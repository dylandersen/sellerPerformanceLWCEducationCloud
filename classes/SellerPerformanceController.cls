public with sharing class SellerPerformanceController {
  @AuraEnabled(cacheable=false)
  public static SellerPerformanceAnalysis getSellerPerformance(Id userId) {
    SellerPerformanceAnalysis analysis = new SellerPerformanceAnalysis();

    try {
      // Query user for basic info
      List<User> userList = [
        SELECT Id, Name, Email
        FROM User
        WHERE Id = :userId
        LIMIT 1
      ];

      if (userList.isEmpty()) {
        throw new AuraHandledException('User not found');
      }

      User user = userList[0];

      // Gather all metrics (last 30 days)
      SellerPerformanceMetrics metrics = gatherMetrics(userId);

      // Calculate DETERMINISTIC score in Apex
      Integer calculatedScore = calculatePerformanceScore(metrics);
      analysis.score = calculatedScore;
      analysis.performanceStatus = getPerformanceStatus(calculatedScore);

      // Generate health assessment tooltip
      metrics.healthAssessmentTooltip = generateHealthAssessmentTooltip(
        calculatedScore,
        analysis.performanceStatus,
        metrics
      );

      // Extract first name from user name
      String firstName = extractFirstName(user.Name);

      // Build detailed context for AI analysis
      String contextData = buildContextData(
        userId,
        user,
        metrics,
        calculatedScore,
        analysis.performanceStatus,
        firstName
      );

      // Call Einstein GenAI for insights and actions ONLY
      String aiResponse = callEinsteinAI(
        contextData,
        calculatedScore,
        analysis.performanceStatus,
        firstName
      );

      // Parse AI response
      parseAIResponse(aiResponse, analysis);

      // Generate trend tooltip after trend is parsed
      metrics.trendTooltip = generateTrendTooltip(analysis.trend, metrics);

      analysis.metrics = metrics;
    } catch (Exception e) {
      System.debug('Error in getSellerPerformance: ' + e.getMessage());
      analysis.errorMessage =
        'Unable to analyze seller performance: ' + e.getMessage();
      analysis.performanceStatus = 'Unknown';
      analysis.score = 0;
      analysis.keyInsights = new List<String>{
        'Error analyzing data. Please try again.'
      };
      analysis.recommendedActions = new List<String>{
        'Refresh to retry analysis.'
      };
    }

    return analysis;
  }

  private static SellerPerformanceMetrics gatherMetrics(Id userId) {
    SellerPerformanceMetrics metrics = new SellerPerformanceMetrics();

    // Query activities from last 30 days
    Date cutoffDate = Date.today().addDays(-30);
    DateTime cutoffDateTime = DateTime.newInstance(
      cutoffDate.year(),
      cutoffDate.month(),
      cutoffDate.day()
    );

    // Query Tasks
    List<Task> tasks = [
      SELECT
        Id,
        Subject,
        Status,
        ActivityDate,
        CreatedDate,
        TaskSubtype,
        Priority,
        CallDurationInSeconds,
        WhoId,
        WhatId
      FROM Task
      WHERE OwnerId = :userId AND CreatedDate >= :cutoffDateTime
      ORDER BY CreatedDate DESC
    ];
    metrics.taskCount = tasks.size();

    // Count calls, completed tasks, scheduled follow-ups
    Integer callCount = 0;
    Integer completedTasks = 0;
    Integer scheduledFollowUps = 0;
    Integer overdueTasks = 0;
    Integer highPriorityTasks = 0;
    Decimal totalCallDuration = 0;

    // Track task types
    Map<String, Integer> taskTypeCounts = new Map<String, Integer>();
    taskTypeCounts.put('Call', 0);
    taskTypeCounts.put('Email', 0);
    taskTypeCounts.put('Meeting', 0);
    taskTypeCounts.put('Other', 0);

    for (Task t : tasks) {
      // Track task types
      String taskType = 'Other';
      if (
        t.TaskSubtype == 'Call' ||
        (String.isNotBlank(t.Subject) &&
        t.Subject.toLowerCase().contains('call'))
      ) {
        taskType = 'Call';
        callCount++;
        if (t.CallDurationInSeconds != null) {
          totalCallDuration += t.CallDurationInSeconds;
        }
      } else if (
        t.TaskSubtype == 'Email' ||
        (String.isNotBlank(t.Subject) &&
        t.Subject.toLowerCase().contains('email'))
      ) {
        taskType = 'Email';
      } else if (
        t.TaskSubtype == 'Event' ||
        (String.isNotBlank(t.Subject) &&
        (t.Subject.toLowerCase().contains('meeting') ||
        t.Subject.toLowerCase().contains('event')))
      ) {
        taskType = 'Meeting';
      }
      taskTypeCounts.put(taskType, taskTypeCounts.get(taskType) + 1);

      if (t.Status == 'Completed') {
        completedTasks++;
      } else if (t.ActivityDate >= Date.today()) {
        scheduledFollowUps++;
      }
      if (t.ActivityDate < Date.today() && t.Status != 'Completed') {
        overdueTasks++;
      }
      if (t.Priority == 'High' || t.Priority == 'Urgent') {
        highPriorityTasks++;
      }
    }
    metrics.callCount = callCount;
    metrics.completedTasksCount = completedTasks;
    metrics.scheduledFollowUpsCount = scheduledFollowUps;

    // Calculate weekly average of completed tasks (30 days = ~4.3 weeks)
    Decimal weeklyAvgCompleted = completedTasks > 0
      ? (Decimal.valueOf(completedTasks) / 4.3)
      : 0;

    // Build calls tooltip
    Decimal avgCallDuration = callCount > 0
      ? (totalCallDuration / callCount / 60)
      : 0;
    metrics.callsTooltip =
      'Total Calls: <b>' +
      String.valueOf(callCount) +
      '</b><br/>' +
      'Completed: <b>' +
      String.valueOf(callCount) +
      '</b><br/>' +
      'Avg Duration: <b>' +
      String.valueOf(avgCallDuration.setScale(1)) +
      ' min</b>';

    // Build tasks tooltip with task type summary and weekly average
    String taskTypeBreakdown = '';
    for (
      String type : new List<String>{ 'Call', 'Email', 'Meeting', 'Other' }
    ) {
      Integer count = taskTypeCounts.get(type);
      if (count > 0) {
        if (String.isNotBlank(taskTypeBreakdown)) {
          taskTypeBreakdown += '<br/>';
        }
        taskTypeBreakdown += type + ': <b>' + String.valueOf(count) + '</b>';
      }
    }

    metrics.tasksTooltip =
      'Total Tasks: <b>' +
      String.valueOf(metrics.taskCount) +
      '</b><br/>' +
      'Completed: <b>' +
      String.valueOf(completedTasks) +
      '</b><br/>' +
      'Weekly Avg Completed: <b>' +
      String.valueOf(weeklyAvgCompleted.setScale(1)) +
      '</b><br/>' +
      'Scheduled: <b>' +
      String.valueOf(scheduledFollowUps) +
      '</b><br/>' +
      'Overdue: <b>' +
      String.valueOf(overdueTasks) +
      '</b><br/>' +
      'High Priority: <b>' +
      String.valueOf(highPriorityTasks) +
      '</b><br/>' +
      'By Type:<br/>' +
      taskTypeBreakdown;

    // Query Events (meetings)
    List<Event> events = [
      SELECT
        Id,
        Subject,
        StartDateTime,
        EndDateTime,
        CreatedDate,
        DurationInMinutes,
        WhatId,
        AccountId,
        WhoId
      FROM Event
      WHERE OwnerId = :userId AND StartDateTime >= :cutoffDateTime
      ORDER BY StartDateTime DESC
    ];
    metrics.meetingCount = events.size();

    // Calculate meeting metrics for tooltip
    Integer completedMeetings = 0;
    Integer scheduledMeetings = 0;
    Decimal totalMeetingDuration = 0;
    Integer highPriorityAccountMeetings = 0;
    Set<Id> highPriorityAccountIds = getHighPriorityAccountIds();

    for (Event e : events) {
      if (e.StartDateTime < DateTime.now()) {
        completedMeetings++;
        if (e.DurationInMinutes != null) {
          totalMeetingDuration += e.DurationInMinutes;
        }
      } else {
        scheduledMeetings++;
      }
      if (e.AccountId != null && highPriorityAccountIds.contains(e.AccountId)) {
        highPriorityAccountMeetings++;
      }
    }
    Decimal avgMeetingDuration = completedMeetings > 0
      ? (totalMeetingDuration / completedMeetings)
      : 0;

    // Build meetings tooltip
    metrics.meetingsTooltip =
      'Total Meetings: <b>' +
      String.valueOf(metrics.meetingCount) +
      '</b><br/>' +
      'Completed: <b>' +
      String.valueOf(completedMeetings) +
      '</b><br/>' +
      'Scheduled: <b>' +
      String.valueOf(scheduledMeetings) +
      '</b><br/>' +
      'Avg Duration: <b>' +
      String.valueOf(avgMeetingDuration.setScale(1)) +
      ' min</b><br/>' +
      'High-Priority Accounts: <b>' +
      String.valueOf(highPriorityAccountMeetings) +
      '</b>';

    // Query EmailMessages
    try {
      List<EmailMessage> emails = [
        SELECT Id, Subject, CreatedDate, Incoming, FromAddress, ToAddress
        FROM EmailMessage
        WHERE CreatedById = :userId AND CreatedDate >= :cutoffDateTime
        ORDER BY CreatedDate DESC
      ];
      metrics.emailCount = emails.size();

      // Calculate email metrics for tooltip
      Integer sentEmails = 0;
      Integer receivedEmails = 0;
      for (EmailMessage em : emails) {
        if (em.Incoming == true) {
          receivedEmails++;
        } else {
          sentEmails++;
        }
      }

      // Build emails tooltip
      metrics.emailsTooltip =
        'Total Emails: <b>' +
        String.valueOf(metrics.emailCount) +
        '</b><br/>' +
        'Sent: <b>' +
        String.valueOf(sentEmails) +
        '</b><br/>' +
        'Received: <b>' +
        String.valueOf(receivedEmails) +
        '</b>';
    } catch (Exception e) {
      System.debug('Error querying emails: ' + e.getMessage());
      metrics.emailCount = 0;
      metrics.emailsTooltip = 'Total Emails: <b>0</b>';
    }

    // Query Opportunities - filter to those created or modified in last 30 days
    List<Opportunity> opportunities = [
      SELECT
        Id,
        Name,
        Amount,
        StageName,
        CloseDate,
        IsClosed,
        IsWon,
        CreatedDate,
        LastModifiedDate
      FROM Opportunity
      WHERE
        OwnerId = :userId
        AND (CreatedDate >= :cutoffDateTime
        OR LastModifiedDate >= :cutoffDateTime)
      ORDER BY CreatedDate DESC
    ];
    metrics.opportunitiesCount = opportunities.size();

    // Calculate opportunity metrics
    Decimal totalPipeline = 0;
    Integer wonCount = 0;
    Integer lostCount = 0;
    Integer newOpps = 0;
    Integer atRisk = 0;
    Integer pastDue = 0;
    Integer stagnant = 0;
    Decimal totalRevenue = 0;
    Decimal totalWonAmount = 0;
    Decimal largestDeal = 0;
    Decimal smallestDeal = Decimal.valueOf(999999999);
    Map<String, Integer> stageCounts = new Map<String, Integer>();
    Set<Id> oppIds = new Set<Id>();

    // Collect healthy and at-risk deals for tooltip
    List<Opportunity> healthyDeals = new List<Opportunity>();
    List<Opportunity> atRiskDeals = new List<Opportunity>();

    Date periodStart = Date.today().addDays(-30);
    Date periodEnd = Date.today();
    DateTime periodStartDateTime = DateTime.newInstance(
      periodStart.year(),
      periodStart.month(),
      periodStart.day()
    );
    DateTime periodEndDateTime = DateTime.newInstance(
      periodEnd.year(),
      periodEnd.month(),
      periodEnd.day(),
      23,
      59,
      59
    );

    for (Opportunity opp : opportunities) {
      oppIds.add(opp.Id);

      if (!opp.IsClosed && opp.Amount != null) {
        totalPipeline += opp.Amount;
      }

      // Only count deals closed in the last 30 days
      if (
        opp.IsWon &&
        opp.LastModifiedDate >= periodStartDateTime &&
        opp.LastModifiedDate <= periodEndDateTime
      ) {
        wonCount++;
        // Calculate revenue from closed-won opportunities in last 30 days
        // Use Amount field as requested
        if (opp.Amount != null) {
          totalRevenue += opp.Amount;
          totalWonAmount += opp.Amount;
          if (opp.Amount > largestDeal) {
            largestDeal = opp.Amount;
          }
          if (opp.Amount < smallestDeal) {
            smallestDeal = opp.Amount;
          }
        }
      } else if (
        opp.IsClosed &&
        !opp.IsWon &&
        opp.LastModifiedDate >= periodStartDateTime &&
        opp.LastModifiedDate <= periodEndDateTime
      ) {
        lostCount++;
      }

      if (opp.CreatedDate.date() >= periodStart) {
        newOpps++;
      }

      // Track healthy and at-risk deals for tooltip
      Boolean isAtRisk = false;
      if (!opp.IsClosed && opp.CloseDate < Date.today()) {
        pastDue++;
        atRisk++;
        isAtRisk = true;
        atRiskDeals.add(opp);
      } else if (!opp.IsClosed && opp.CloseDate < Date.today().addDays(7)) {
        atRisk++;
        isAtRisk = true;
        atRiskDeals.add(opp);
      } else if (!opp.IsClosed) {
        // Healthy deal (open and not at-risk)
        healthyDeals.add(opp);
      }

      // Track stage counts
      if (opp.StageName != null) {
        if (stageCounts.containsKey(opp.StageName)) {
          stageCounts.put(opp.StageName, stageCounts.get(opp.StageName) + 1);
        } else {
          stageCounts.put(opp.StageName, 1);
        }
      }
    }

    metrics.totalPipelineValue = totalPipeline;
    metrics.opportunitiesWonCount = wonCount;
    metrics.opportunitiesLostCount = lostCount;
    metrics.newOpportunitiesCount = newOpps;
    metrics.atRiskDealsCount = atRisk;
    metrics.pastDueCloseDatesCount = pastDue;
    metrics.totalRevenue = totalRevenue;
    metrics.dealsClosedWon = wonCount;
    metrics.dealsClosedLost = lostCount;

    // Calculate win rate
    Integer totalClosed = wonCount + lostCount;
    if (totalClosed > 0) {
      metrics.winRate =
        (Decimal.valueOf(wonCount) / Decimal.valueOf(totalClosed)) * 100;
    }

    // Calculate average deal size
    if (wonCount > 0 && totalWonAmount > 0) {
      metrics.avgDealSize = totalWonAmount / wonCount;
    }

    // Build pipeline value tooltip
    String stageBreakdown = '';
    for (String stage : stageCounts.keySet()) {
      if (String.isNotBlank(stageBreakdown)) {
        stageBreakdown += '<br/>';
      }
      stageBreakdown +=
        stage +
        ': <b>' +
        String.valueOf(stageCounts.get(stage)) +
        '</b>';
    }
    metrics.pipelineValueTooltip =
      'Total Pipeline: <b>$' +
      formatCurrency(totalPipeline) +
      '</b><br/>' +
      'Largest Deal: <b>$' +
      formatCurrency(largestDeal) +
      '</b><br/>' +
      'Avg Deal Size: <b>$' +
      formatCurrency(metrics.avgDealSize) +
      '</b><br/>' +
      'By Stage:<br/>' +
      stageBreakdown;

    // Build win rate tooltip
    metrics.winRateTooltip =
      'Win Rate: <b>' +
      String.valueOf(metrics.winRate.setScale(1)) +
      '%</b><br/>' +
      'Won: <b>' +
      String.valueOf(wonCount) +
      '</b><br/>' +
      'Lost: <b>' +
      String.valueOf(lostCount) +
      '</b><br/>' +
      'Total Closed: <b>' +
      String.valueOf(totalClosed) +
      '</b>';

    // Build revenue tooltip
    metrics.revenueTooltip =
      'Last 30 Days: <b>$' +
      formatCurrency(totalRevenue) +
      '</b><br/>' +
      'Largest Deal: <b>$' +
      formatCurrency(largestDeal) +
      '</b><br/>' +
      'Deals Closed Won: <b>' +
      String.valueOf(wonCount) +
      '</b>';

    // Build opportunities tooltip
    metrics.opportunitiesTooltip =
      'Total Opportunities: <b>' +
      String.valueOf(metrics.opportunitiesCount) +
      '</b><br/>' +
      'New This Period: <b>' +
      String.valueOf(newOpps) +
      '</b><br/>' +
      'Stagnant Deals: <b>' +
      String.valueOf(stagnant) +
      '</b>';

    // Build at-risk deals tooltip
    Decimal atRiskValue = 0;
    for (Opportunity opp : opportunities) {
      if (!opp.IsClosed && opp.CloseDate < Date.today() && opp.Amount != null) {
        atRiskValue += opp.Amount;
      }
    }
    metrics.atRiskDealsTooltip =
      'At-Risk Deals: <b>' +
      String.valueOf(atRisk) +
      '</b><br/>' +
      'Total Value: <b>$' +
      formatCurrency(atRiskValue) +
      '</b><br/>' +
      'Past Due: <b>' +
      String.valueOf(pastDue) +
      '</b>';

    // Build pipeline health tooltip
    String pipelineHealthMessage = '';
    if (!healthyDeals.isEmpty()) {
      Opportunity firstHealthy = healthyDeals[0];
      String healthyName = firstHealthy.Name != null
        ? firstHealthy.Name
        : 'Unnamed Deal';
      String healthyAmount = firstHealthy.Amount != null
        ? formatCurrency(firstHealthy.Amount)
        : '$0';
      pipelineHealthMessage =
        'Focus on your healthy deal, <b>' +
        healthyName +
        ' - $' +
        healthyAmount +
        '</b>';
    }

    if (!atRiskDeals.isEmpty()) {
      Integer atRiskCount = Math.min(2, atRiskDeals.size());
      List<String> atRiskNames = new List<String>();
      for (Integer i = 0; i < atRiskCount; i++) {
        Opportunity atRiskOpp = atRiskDeals[i];
        String atRiskName = atRiskOpp.Name != null
          ? atRiskOpp.Name
          : 'Unnamed Deal';
        String atRiskAmount = atRiskOpp.Amount != null
          ? formatCurrency(atRiskOpp.Amount)
          : '$0';
        atRiskNames.add('<b>' + atRiskName + ' - $' + atRiskAmount + '</b>');
      }

      if (String.isNotBlank(pipelineHealthMessage)) {
        pipelineHealthMessage +=
          ' and make sure you are paying attention to these important at-risk deals: ' +
          String.join(atRiskNames, ' and ');
      } else {
        pipelineHealthMessage =
          'Make sure you are paying attention to these important at-risk deals: ' +
          String.join(atRiskNames, ' and ');
      }
    }

    if (String.isBlank(pipelineHealthMessage)) {
      pipelineHealthMessage = 'No active deals to display.';
    }

    metrics.pipelineHealthTooltip = pipelineHealthMessage;

    // Query stage history for stagnant deals and deal velocity
    // Need full history to detect stagnant deals, but will filter usage to last 30 days
    if (!oppIds.isEmpty()) {
      // Query all stage history for opportunities in our set (to detect stagnant deals)
      List<OpportunityFieldHistory> allStageHistory = [
        SELECT OpportunityId, Field, OldValue, NewValue, CreatedDate
        FROM OpportunityFieldHistory
        WHERE OpportunityId IN :oppIds AND Field = 'StageName'
        ORDER BY CreatedDate DESC
      ];

      // Filter to recent history for velocity calculation
      List<OpportunityFieldHistory> recentStageHistory = new List<OpportunityFieldHistory>();
      for (OpportunityFieldHistory hist : allStageHistory) {
        if (hist.CreatedDate >= periodStartDateTime) {
          recentStageHistory.add(hist);
        }
      }

      // Calculate stagnant deals (no stage change in 30+ days) - only from opportunities in last 30 days
      Map<Id, Date> lastStageChange = new Map<Id, Date>();
      for (OpportunityFieldHistory hist : allStageHistory) {
        if (!lastStageChange.containsKey(hist.OpportunityId)) {
          lastStageChange.put(hist.OpportunityId, hist.CreatedDate.date());
        }
      }

      for (Opportunity opp : opportunities) {
        if (!opp.IsClosed) {
          Date lastChange = lastStageChange.get(opp.Id);
          if (lastChange == null) {
            lastChange = opp.CreatedDate.date();
          }
          Integer daysSinceChange = lastChange.daysBetween(Date.today());
          if (daysSinceChange >= 30) {
            stagnant++;
          }
        }
      }
      metrics.stagnantDealsCount = stagnant;

      // Calculate deal velocity (average days between stage transitions)
      // First try: Use all stage history (not just last 30 days) for opportunities in our set
      // This gives us more data points to calculate velocity
      String velocityCalculationMethod = '';
      Integer velocityDataPoints = 0;
      Integer velocityOpportunitiesUsed = 0;

      if (!allStageHistory.isEmpty()) {
        List<Long> stageTransitionDays = new List<Long>();
        Map<Id, List<OpportunityFieldHistory>> oppHistoryMap = new Map<Id, List<OpportunityFieldHistory>>();

        // Group all stage history by opportunity
        for (OpportunityFieldHistory hist : allStageHistory) {
          if (!oppHistoryMap.containsKey(hist.OpportunityId)) {
            oppHistoryMap.put(
              hist.OpportunityId,
              new List<OpportunityFieldHistory>()
            );
          }
          oppHistoryMap.get(hist.OpportunityId).add(hist);
        }

        // Calculate velocity for each opportunity with at least 2 stage changes
        Set<Id> oppsWithTransitions = new Set<Id>();
        for (Id oppId : oppHistoryMap.keySet()) {
          List<OpportunityFieldHistory> histList = oppHistoryMap.get(oppId);
          histList.sort(new HistoryDateComparator());
          // Need at least 2 stage changes per opportunity to calculate velocity
          if (histList.size() > 1) {
            oppsWithTransitions.add(oppId);
            for (Integer i = 1; i < histList.size(); i++) {
              // Subtract older from newer to get positive days
              Long daysDiff =
                histList[i].CreatedDate.getTime() -
                histList[i - 1].CreatedDate.getTime();
              daysDiff = daysDiff / (1000 * 60 * 60 * 24);
              if (daysDiff > 0 && daysDiff < 365) {
                stageTransitionDays.add(daysDiff);
              }
            }
          }
        }

        if (!stageTransitionDays.isEmpty()) {
          Long totalDays = 0;
          for (Long days : stageTransitionDays) {
            totalDays += days;
          }
          metrics.dealVelocity =
            Decimal.valueOf(totalDays) /
            Decimal.valueOf(stageTransitionDays.size());
          velocityCalculationMethod = 'Stage Transitions';
          velocityDataPoints = stageTransitionDays.size();
          velocityOpportunitiesUsed = oppsWithTransitions.size();
        }
      }

      // Fallback 1: Calculate velocity from CreatedDate to CloseDate for ALL closed deals won
      // (not just those modified in last 30 days - this gives us more data)
      if (metrics.dealVelocity == 0) {
        List<Decimal> dealDurations = new List<Decimal>();
        for (Opportunity opp : opportunities) {
          if (
            opp.IsClosed &&
            opp.IsWon &&
            opp.CreatedDate != null &&
            opp.CloseDate != null
          ) {
            Date createdDate = opp.CreatedDate.date();
            Date closeDate = opp.CloseDate;
            Integer daysDiff = createdDate.daysBetween(closeDate);
            if (daysDiff > 0 && daysDiff < 365) {
              dealDurations.add(Decimal.valueOf(daysDiff));
            }
          }
        }
        if (!dealDurations.isEmpty()) {
          Decimal totalDays = 0;
          for (Decimal days : dealDurations) {
            totalDays += days;
          }
          metrics.dealVelocity =
            totalDays / Decimal.valueOf(dealDurations.size());
          velocityCalculationMethod = 'Closed-Won Deals';
          velocityDataPoints = dealDurations.size();
          velocityOpportunitiesUsed = dealDurations.size();
        }
      }

      // Fallback 2: Calculate velocity from CreatedDate to current date for open opportunities
      // This helps when there are no closed deals but there are open opportunities
      if (metrics.dealVelocity == 0) {
        List<Decimal> dealDurations = new List<Decimal>();
        Date today = Date.today();
        for (Opportunity opp : opportunities) {
          if (!opp.IsClosed && opp.CreatedDate != null) {
            Date createdDate = opp.CreatedDate.date();
            Integer daysDiff = createdDate.daysBetween(today);
            if (daysDiff > 0 && daysDiff < 365) {
              dealDurations.add(Decimal.valueOf(daysDiff));
            }
          }
        }
        if (!dealDurations.isEmpty()) {
          Decimal totalDays = 0;
          for (Decimal days : dealDurations) {
            totalDays += days;
          }
          // For open deals, divide by number of stages (assume average 4 stages)
          // This gives us an approximate velocity
          Decimal avgStages = 4.0;
          metrics.dealVelocity =
            (totalDays / Decimal.valueOf(dealDurations.size())) / avgStages;
          velocityCalculationMethod = 'Open Deals (Estimated)';
          velocityDataPoints = dealDurations.size();
          velocityOpportunitiesUsed = dealDurations.size();
        }
      }

      // Build deal velocity tooltip with calculation details
      if (metrics.dealVelocity > 0) {
        String tooltipText =
          'Deal Velocity: <b>' +
          String.valueOf(metrics.dealVelocity.setScale(1)) +
          ' days</b><br/>' +
          'Calculation Method: <b>' +
          velocityCalculationMethod +
          '</b><br/>';

        if (velocityCalculationMethod == 'Stage Transitions') {
          tooltipText +=
            'Based on <b>' +
            String.valueOf(velocityDataPoints) +
            ' stage transitions</b> across <b>' +
            String.valueOf(velocityOpportunitiesUsed) +
            ' opportunities</b><br/>' +
            'Average days between each stage change in your pipeline.';
        } else if (velocityCalculationMethod == 'Closed-Won Deals') {
          tooltipText +=
            'Based on <b>' +
            String.valueOf(velocityOpportunitiesUsed) +
            ' closed-won deals</b><br/>' +
            'Average days from creation to close date, divided by typical number of stages.';
        } else if (velocityCalculationMethod == 'Open Deals (Estimated)') {
          tooltipText +=
            'Based on <b>' +
            String.valueOf(velocityOpportunitiesUsed) +
            ' open opportunities</b><br/>' +
            'Estimated average days per stage based on days since creation (assuming 4 stages per deal).';
        }

        metrics.dealVelocityTooltip = tooltipText;
      } else {
        metrics.dealVelocityTooltip =
          'Deal Velocity: <b>No Data</b><br/>' +
          'Unable to calculate velocity. Need at least 2 stage transitions, closed-won deals, or open opportunities with creation dates.';
      }

      // Count deals advancing (stage changes in period) - only from last 30 days
      Integer advancing = 0;
      for (OpportunityFieldHistory hist : recentStageHistory) {
        advancing++;
      }
      metrics.dealsAdvancingCount = advancing;
    }

    // Query contacts engaged from activities
    Set<Id> contactIds = new Set<Id>();
    for (Task t : tasks) {
      if (t.WhoId != null && String.valueOf(t.WhoId).startsWith('003')) {
        contactIds.add(t.WhoId);
      }
    }
    for (Event e : events) {
      if (e.WhoId != null && String.valueOf(e.WhoId).startsWith('003')) {
        contactIds.add(e.WhoId);
      }
    }
    metrics.contactsEngagedCount = contactIds.size();

    // Calculate new relationships (first activity in period)
    Integer newRelationships = 0;
    if (!contactIds.isEmpty()) {
      List<AggregateResult> firstActivities = [
        SELECT MIN(CreatedDate) firstDate, WhoId
        FROM Task
        WHERE WhoId IN :contactIds AND OwnerId = :userId
        GROUP BY WhoId
      ];
      for (AggregateResult ar : firstActivities) {
        Date firstDate = Date.valueOf(ar.get('firstDate'));
        if (firstDate >= periodStart) {
          newRelationships++;
        }
      }
    }
    metrics.newRelationshipsCount = newRelationships;

    // Count high-priority account interactions
    Integer highPriorityInteractions = 0;
    if (!highPriorityAccountIds.isEmpty()) {
      for (Task t : tasks) {
        if (t.WhatId != null && String.valueOf(t.WhatId).startsWith('001')) {
          // Need to check if related to high-priority account
          // This would require additional query or relationship traversal
        }
      }
      for (Event e : events) {
        if (
          e.AccountId != null && highPriorityAccountIds.contains(e.AccountId)
        ) {
          highPriorityInteractions++;
        }
      }
    }
    metrics.highPriorityAccountInteractions = highPriorityInteractions;

    // Build contacts engaged tooltip
    metrics.contactsEngagedTooltip =
      'Contacts Engaged: <b>' +
      String.valueOf(metrics.contactsEngagedCount) +
      '</b><br/>' +
      'New Relationships: <b>' +
      String.valueOf(newRelationships) +
      '</b><br/>' +
      'High-Priority Interactions: <b>' +
      String.valueOf(highPriorityInteractions) +
      '</b>';

    return metrics;
  }

  private static Set<Id> getHighPriorityAccountIds() {
    // Query accounts with high priority indicator
    // This assumes there might be a custom field or we use a standard field
    // For now, return empty set - can be enhanced based on org configuration
    Set<Id> accountIds = new Set<Id>();
    try {
      List<Account> highPriorityAccounts = [
        SELECT Id
        FROM Account
        WHERE Type = 'Customer'
        LIMIT 100
      ];
      for (Account acc : highPriorityAccounts) {
        accountIds.add(acc.Id);
      }
    } catch (Exception e) {
      System.debug('Error querying high priority accounts: ' + e.getMessage());
    }
    return accountIds;
  }

  private static String formatCurrency(Decimal amount) {
    if (amount == null || amount == 0) {
      return '0';
    }
    if (amount >= 1000000) {
      return String.valueOf((amount / 1000000).setScale(1)) + 'M';
    } else if (amount >= 1000) {
      return String.valueOf((amount / 1000).setScale(1)) + 'K';
    }
    return String.valueOf(amount.setScale(0));
  }

  private static Integer calculatePerformanceScore(
    SellerPerformanceMetrics metrics
  ) {
    Integer score = 0;

    // 1. Activity Volume Score (30 points max)
    Integer totalActivities =
      metrics.callCount +
      metrics.emailCount +
      metrics.meetingCount +
      metrics.taskCount;
    if (totalActivities >= 100) {
      score += 30;
    } else if (totalActivities >= 75) {
      score += 25;
    } else if (totalActivities >= 50) {
      score += 20;
    } else if (totalActivities >= 25) {
      score += 15;
    } else if (totalActivities >= 10) {
      score += 10;
    } else if (totalActivities >= 5) {
      score += 5;
    }

    // 2. Pipeline Health Score (25 points max)
    // Pipeline value component (15 points)
    if (metrics.totalPipelineValue >= 1000000) {
      score += 15;
    } else if (metrics.totalPipelineValue >= 500000) {
      score += 12;
    } else if (metrics.totalPipelineValue >= 250000) {
      score += 10;
    } else if (metrics.totalPipelineValue >= 100000) {
      score += 7;
    } else if (metrics.totalPipelineValue >= 50000) {
      score += 5;
    } else if (metrics.totalPipelineValue > 0) {
      score += 2;
    }

    // Deal velocity component (5 points)
    if (metrics.dealVelocity > 0) {
      if (metrics.dealVelocity <= 7) {
        score += 5; // Fast velocity (7 days or less)
      } else if (metrics.dealVelocity <= 14) {
        score += 4; // Good velocity (14 days or less)
      } else if (metrics.dealVelocity <= 21) {
        score += 3; // Moderate velocity
      } else if (metrics.dealVelocity <= 30) {
        score += 2; // Slow velocity
      }
    }

    // At-risk deals penalty (5 points)
    if (metrics.atRiskDealsCount == 0) {
      score += 5;
    } else if (metrics.atRiskDealsCount <= 2) {
      score += 3;
    } else if (metrics.atRiskDealsCount <= 5) {
      score += 1;
    } else {
      score -= 2; // Penalty for many at-risk deals
    }

    // 3. Deal Execution Score (25 points max)
    // Win rate component (15 points)
    if (metrics.winRate >= 50) {
      score += 15;
    } else if (metrics.winRate >= 40) {
      score += 12;
    } else if (metrics.winRate >= 30) {
      score += 10;
    } else if (metrics.winRate >= 20) {
      score += 7;
    } else if (metrics.winRate > 0) {
      score += 5;
    }

    // Revenue component (10 points)
    if (metrics.totalRevenue >= 500000) {
      score += 10;
    } else if (metrics.totalRevenue >= 250000) {
      score += 8;
    } else if (metrics.totalRevenue >= 100000) {
      score += 6;
    } else if (metrics.totalRevenue >= 50000) {
      score += 4;
    } else if (metrics.totalRevenue > 0) {
      score += 2;
    }

    // 4. Relationship Building Score (20 points max)
    // Contacts engaged component (12 points)
    if (metrics.contactsEngagedCount >= 50) {
      score += 12;
    } else if (metrics.contactsEngagedCount >= 30) {
      score += 10;
    } else if (metrics.contactsEngagedCount >= 20) {
      score += 8;
    } else if (metrics.contactsEngagedCount >= 10) {
      score += 6;
    } else if (metrics.contactsEngagedCount >= 5) {
      score += 4;
    } else if (metrics.contactsEngagedCount > 0) {
      score += 2;
    }

    // New relationships component (8 points)
    if (metrics.newRelationshipsCount >= 10) {
      score += 8;
    } else if (metrics.newRelationshipsCount >= 5) {
      score += 6;
    } else if (metrics.newRelationshipsCount >= 3) {
      score += 4;
    } else if (metrics.newRelationshipsCount >= 1) {
      score += 2;
    }

    // PENALTIES
    if (metrics.stagnantDealsCount > 5) {
      score -= 5; // Many stagnant deals
    } else if (metrics.stagnantDealsCount > 2) {
      score -= 2; // Some stagnant deals
    }

    if (metrics.pastDueCloseDatesCount > 5) {
      score -= 5; // Many past-due deals
    } else if (metrics.pastDueCloseDatesCount > 2) {
      score -= 2; // Some past-due deals
    }

    // Ensure score is between 0 and 100
    if (score < 0) {
      score = 0;
    } else if (score > 100) {
      score = 100;
    }

    return score;
  }

  private static String getPerformanceStatus(Integer score) {
    if (score >= 80) {
      return 'Crushing It';
    } else if (score >= 60) {
      return 'On Target';
    } else if (score >= 40) {
      return 'Needs Attention';
    }
    return 'Struggling';
  }

  private static String generateHealthAssessmentTooltip(
    Integer score,
    String status,
    SellerPerformanceMetrics metrics
  ) {
    String tooltip = 'Your score of <b>' + String.valueOf(score) + '</b> is ';

    // Determine target range based on status
    String targetRange = '';
    String whyText = '';
    String improvementText = '';

    if (status == 'Crushing It') {
      targetRange = '80+';
      whyText = 'You\'re exceeding expectations with strong performance across all key areas.';
    } else if (status == 'On Target') {
      targetRange = '60-79';
      whyText = 'You\'re meeting your performance targets. ';
    } else if (status == 'Needs Attention') {
      targetRange = '40-59';
      whyText = 'Your score is below the target range of 60-79. ';
    } else {
      targetRange = 'below 40';
      whyText = 'Your score is significantly below target. ';
    }

    tooltip += 'within your target of <b>' + targetRange + '</b>.<br/><br/>';
    tooltip += '<b>Why this score?</b><br/>';
    tooltip += whyText;

    // Add specific data points
    Integer totalActivities =
      (metrics.callCount != null ? metrics.callCount : 0) +
      (metrics.emailCount != null ? metrics.emailCount : 0) +
      (metrics.meetingCount != null ? metrics.meetingCount : 0) +
      (metrics.taskCount != null ? metrics.taskCount : 0);

    if (totalActivities > 0) {
      tooltip +=
        'You\'ve completed <b>' +
        String.valueOf(totalActivities) +
        ' activities</b> in the last 30 days';
      if (metrics.winRate != null && metrics.winRate > 0) {
        tooltip +=
          ' with a <b>' +
          String.valueOf(metrics.winRate.setScale(1)) +
          '% win rate</b>';
      }
      tooltip += '. ';
    }

    if (metrics.totalPipelineValue != null && metrics.totalPipelineValue > 0) {
      String pipelineFormatted = formatCurrency(metrics.totalPipelineValue);
      tooltip += 'Your pipeline value is <b>$' + pipelineFormatted + '</b>. ';
    }

    if (metrics.atRiskDealsCount != null && metrics.atRiskDealsCount > 0) {
      tooltip +=
        'You have <b>' +
        String.valueOf(metrics.atRiskDealsCount) +
        ' at-risk deals</b> that need attention. ';
    }

    tooltip += '<br/><br/><b>How to improve:</b><br/>';

    // Provide improvement suggestions based on score
    if (score < 60) {
      if (totalActivities < 50) {
        tooltip += '• Increase activity volume - aim for at least 50 activities per month<br/>';
      }
      if (
        metrics.totalPipelineValue == null ||
        metrics.totalPipelineValue < 100000
      ) {
        tooltip += '• Build your pipeline - focus on creating new opportunities worth at least $100K<br/>';
      }
      if (metrics.atRiskDealsCount != null && metrics.atRiskDealsCount > 0) {
        tooltip += '• Address at-risk deals - review close dates and update opportunities<br/>';
      }
      if (metrics.winRate == null || metrics.winRate < 30) {
        tooltip += '• Improve win rate - focus on qualifying opportunities better and following up consistently<br/>';
      }
    } else if (score < 80) {
      tooltip += '• Maintain your current activity levels<br/>';
      if (
        metrics.totalPipelineValue != null &&
        metrics.totalPipelineValue < 500000
      ) {
        tooltip += '• Grow pipeline value - aim for $500K+ to reach the next level<br/>';
      }
      if (metrics.dealVelocity != null && metrics.dealVelocity > 14) {
        tooltip += '• Accelerate deal velocity - work on moving deals through stages faster<br/>';
      }
      tooltip += '• Focus on relationship building - engage with more contacts and key accounts<br/>';
    } else {
      tooltip += '• Keep up the excellent work!<br/>';
      tooltip += '• Share best practices with your team<br/>';
      tooltip += '• Continue building relationships and expanding your pipeline<br/>';
    }

    return tooltip;
  }

  private static String generateTrendTooltip(
    String trend,
    SellerPerformanceMetrics metrics
  ) {
    String tooltip = '';

    // Determine trend direction
    String trendDirection = '';
    if (String.isNotBlank(trend)) {
      String trendLower = trend.toLowerCase();
      if (trendLower.contains('accelerating')) {
        trendDirection = 'Accelerating';
      } else if (trendLower.contains('declining')) {
        trendDirection = 'Declining';
      } else {
        trendDirection = 'Steady';
      }
    } else {
      trendDirection = 'Steady';
    }

    tooltip += 'Your 30-day trend is <b>' + trendDirection + '</b>.<br/><br/>';
    tooltip += '<b>Why this trend?</b><br/>';

    // Calculate total activities
    Integer totalActivities =
      (metrics.callCount != null ? metrics.callCount : 0) +
      (metrics.emailCount != null ? metrics.emailCount : 0) +
      (metrics.meetingCount != null ? metrics.meetingCount : 0) +
      (metrics.taskCount != null ? metrics.taskCount : 0);

    // Analyze activity patterns
    if (totalActivities >= 75) {
      tooltip +=
        'You\'ve been highly active with <b>' +
        String.valueOf(totalActivities) +
        ' activities</b> in the last 30 days. ';
    } else if (totalActivities >= 50) {
      tooltip +=
        'You\'ve maintained good activity levels with <b>' +
        String.valueOf(totalActivities) +
        ' activities</b>. ';
    } else if (totalActivities >= 25) {
      tooltip +=
        'Your activity level is moderate with <b>' +
        String.valueOf(totalActivities) +
        ' activities</b>. ';
    } else if (totalActivities > 0) {
      tooltip +=
        'Your activity level is lower with <b>' +
        String.valueOf(totalActivities) +
        ' activities</b>. ';
    } else {
      tooltip += 'You have <b>no recorded activities</b> in the last 30 days. ';
    }

    // Analyze pipeline momentum
    if (
      metrics.newOpportunitiesCount != null &&
      metrics.newOpportunitiesCount > 0
    ) {
      tooltip +=
        'You\'ve created <b>' +
        String.valueOf(metrics.newOpportunitiesCount) +
        ' new opportunities</b>. ';
    }

    if (
      metrics.dealsAdvancingCount != null &&
      metrics.dealsAdvancingCount > 0
    ) {
      tooltip +=
        '<b>' +
        String.valueOf(metrics.dealsAdvancingCount) +
        ' deals</b> have advanced stages. ';
    }

    // Analyze deal execution
    if (metrics.dealsClosedWon != null && metrics.dealsClosedWon > 0) {
      tooltip +=
        'You\'ve closed <b>' +
        String.valueOf(metrics.dealsClosedWon) +
        ' deals</b> as won';
      if (metrics.winRate != null && metrics.winRate > 0) {
        tooltip +=
          ' with a <b>' +
          String.valueOf(metrics.winRate.setScale(1)) +
          '% win rate</b>';
      }
      tooltip += '. ';
    }

    // Analyze pipeline health
    if (metrics.stagnantDealsCount != null && metrics.stagnantDealsCount > 0) {
      tooltip +=
        'You have <b>' +
        String.valueOf(metrics.stagnantDealsCount) +
        ' stagnant deals</b> that haven\'t progressed in 30+ days. ';
    }

    if (metrics.atRiskDealsCount != null && metrics.atRiskDealsCount > 0) {
      tooltip +=
        '<b>' +
        String.valueOf(metrics.atRiskDealsCount) +
        ' deals</b> are at-risk with close dates approaching. ';
    }

    // Analyze deal velocity
    if (metrics.dealVelocity != null && metrics.dealVelocity > 0) {
      if (metrics.dealVelocity <= 7) {
        tooltip +=
          'Your deal velocity is <b>fast</b> at ' +
          String.valueOf(metrics.dealVelocity.setScale(1)) +
          ' days per stage. ';
      } else if (metrics.dealVelocity <= 14) {
        tooltip +=
          'Your deal velocity is <b>good</b> at ' +
          String.valueOf(metrics.dealVelocity.setScale(1)) +
          ' days per stage. ';
      } else if (metrics.dealVelocity <= 21) {
        tooltip +=
          'Your deal velocity is <b>moderate</b> at ' +
          String.valueOf(metrics.dealVelocity.setScale(1)) +
          ' days per stage. ';
      } else {
        tooltip +=
          'Your deal velocity is <b>slower</b> at ' +
          String.valueOf(metrics.dealVelocity.setScale(1)) +
          ' days per stage. ';
      }
    }

    tooltip += '<br/><br/><b>What this means:</b><br/>';

    // Provide trend-specific insights
    if (trendDirection == 'Accelerating') {
      tooltip += '• Your performance is improving - keep up the momentum!<br/>';
      if (totalActivities >= 75) {
        tooltip += '• High activity levels are driving your success<br/>';
      }
      if (
        metrics.dealsAdvancingCount != null &&
        metrics.dealsAdvancingCount > 0
      ) {
        tooltip += '• Deals moving through stages indicate strong pipeline momentum<br/>';
      }
      if (metrics.dealVelocity != null && metrics.dealVelocity <= 14) {
        tooltip += '• Fast deal velocity shows effective execution<br/>';
      }
    } else if (trendDirection == 'Declining') {
      tooltip += '• Your performance needs attention - focus on key areas<br/>';
      if (totalActivities < 50) {
        tooltip += '• Low activity levels may be impacting your results<br/>';
      }
      if (
        metrics.stagnantDealsCount != null &&
        metrics.stagnantDealsCount > 0
      ) {
        tooltip += '• Stagnant deals need immediate attention to restart momentum<br/>';
      }
      if (metrics.atRiskDealsCount != null && metrics.atRiskDealsCount > 0) {
        tooltip += '• At-risk deals require follow-up to prevent losses<br/>';
      }
    } else {
      tooltip += '• Your performance is holding steady<br/>';
      tooltip += '• Maintain current activity levels to sustain results<br/>';
      if (
        metrics.newOpportunitiesCount != null &&
        metrics.newOpportunitiesCount == 0
      ) {
        tooltip += '• Consider adding new opportunities to accelerate growth<br/>';
      }
    }

    return tooltip;
  }

  private static String extractFirstName(String fullName) {
    if (String.isBlank(fullName)) {
      return 'the seller';
    }
    List<String> nameParts = fullName.split(' ', 2);
    if (nameParts.size() > 0 && String.isNotBlank(nameParts[0])) {
      return nameParts[0];
    }
    return 'the seller';
  }

  private static String buildContextData(
    Id userId,
    User user,
    SellerPerformanceMetrics metrics,
    Integer calculatedScore,
    String performanceStatus,
    String firstName
  ) {
    List<String> contextParts = new List<String>();

    contextParts.add('## SELLER PERFORMANCE ANALYSIS\n\n');
    contextParts.add(
      '**IMPORTANT CONTEXT:** Today is ' +
        Date.today().format() +
        '. Use this current date for all calculations.\n\n'
    );

    contextParts.add('### Seller Details\n');
    contextParts.add('- **Full Name:** ' + user.Name + '\n');
    contextParts.add('- **First Name:** ' + firstName + '\n');
    contextParts.add(
      '- **Email:** ' +
        (String.isNotBlank(user.Email) ? user.Email : 'No email') +
        '\n\n'
    );

    contextParts.add('### Activity Metrics (Last 30 Days)\n');
    contextParts.add(
      '- **Calls:** ' + String.valueOf(metrics.callCount) + '\n'
    );
    contextParts.add(
      '- **Emails:** ' + String.valueOf(metrics.emailCount) + '\n'
    );
    contextParts.add(
      '- **Meetings:** ' + String.valueOf(metrics.meetingCount) + '\n'
    );
    contextParts.add(
      '- **Tasks:** ' + String.valueOf(metrics.taskCount) + '\n'
    );
    contextParts.add(
      '- **Completed Tasks:** ' +
        String.valueOf(metrics.completedTasksCount) +
        '\n'
    );
    contextParts.add(
      '- **Scheduled Follow-ups:** ' +
        String.valueOf(metrics.scheduledFollowUpsCount) +
        '\n\n'
    );

    contextParts.add('### Pipeline Management\n');
    contextParts.add(
      '- **Total Pipeline Value:** $' +
        formatCurrency(metrics.totalPipelineValue) +
        '\n'
    );
    contextParts.add(
      '- **Opportunities:** ' +
        String.valueOf(metrics.opportunitiesCount) +
        '\n'
    );
    contextParts.add(
      '- **New Opportunities:** ' +
        String.valueOf(metrics.newOpportunitiesCount) +
        '\n'
    );
    contextParts.add(
      '- **Stagnant Deals:** ' +
        String.valueOf(metrics.stagnantDealsCount) +
        '\n'
    );
    contextParts.add(
      '- **Deal Velocity:** ' +
        String.valueOf(metrics.dealVelocity.setScale(1)) +
        ' days\n'
    );
    contextParts.add(
      '- **Deals Advancing:** ' +
        String.valueOf(metrics.dealsAdvancingCount) +
        '\n\n'
    );

    contextParts.add('### Deal Execution\n');
    contextParts.add(
      '- **Win Rate:** ' + String.valueOf(metrics.winRate.setScale(1)) + '%\n'
    );
    contextParts.add(
      '- **Total Revenue:** $' + formatCurrency(metrics.totalRevenue) + '\n'
    );
    contextParts.add(
      '- **Avg Deal Size:** $' + formatCurrency(metrics.avgDealSize) + '\n'
    );
    contextParts.add(
      '- **Deals Closed Won:** ' + String.valueOf(metrics.dealsClosedWon) + '\n'
    );
    contextParts.add(
      '- **Deals Closed Lost:** ' +
        String.valueOf(metrics.dealsClosedLost) +
        '\n\n'
    );

    contextParts.add('### Relationship Building\n');
    contextParts.add(
      '- **Contacts Engaged:** ' +
        String.valueOf(metrics.contactsEngagedCount) +
        '\n'
    );
    contextParts.add(
      '- **New Relationships:** ' +
        String.valueOf(metrics.newRelationshipsCount) +
        '\n'
    );
    contextParts.add(
      '- **High-Priority Interactions:** ' +
        String.valueOf(metrics.highPriorityAccountInteractions) +
        '\n\n'
    );

    contextParts.add('### Pipeline Health\n');
    contextParts.add(
      '- **At-Risk Deals:** ' + String.valueOf(metrics.atRiskDealsCount) + '\n'
    );
    contextParts.add(
      '- **Past-Due Close Dates:** ' +
        String.valueOf(metrics.pastDueCloseDatesCount) +
        '\n\n'
    );

    contextParts.add('## CALCULATED PERFORMANCE SCORE\n\n');
    contextParts.add(
      '**The performance score has been CALCULATED as: ' +
        calculatedScore +
        '/100**\n'
    );
    contextParts.add(
      '**Status Classification: ' + performanceStatus + '**\n\n'
    );
    contextParts.add(
      '**IMPORTANT:** Do NOT recalculate or modify this score. Accept it as final. Your job is ONLY to provide insights and actions based on this score and the data provided.\n\n'
    );

    return String.join(contextParts, '');
  }

  private static String callEinsteinAI(
    String contextData,
    Integer calculatedScore,
    String performanceStatus,
    String firstName
  ) {
    try {
      String modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';

      List<String> promptParts = new List<String>();

      promptParts.add(contextData);

      promptParts.add('## YOUR TASK\n\n');
      promptParts.add(
        'Based on the calculated score (' +
          calculatedScore +
          '/100), performance status (' +
          performanceStatus +
          '), and all metrics provided, generate:\n'
      );
      promptParts.add(
        '1. A trend analysis (Accelerating, Steady, or Declining)\n'
      );
      promptParts.add('2. 5 key insights about the seller performance\n');
      promptParts.add('3. 5 specific, actionable recommendations\n\n');

      promptParts.add('## OUTPUT FORMAT\n\n');
      promptParts.add(
        'Return your analysis in this EXACT format:\n\n' +
          '**TREND:** [Accelerating|Steady|Declining]\n\n' +
          '**KEY INSIGHTS:**\n' +
          '- [Insight 1]\n' +
          '- [Insight 2]\n' +
          '- [Insight 3]\n' +
          '- [Insight 4]\n' +
          '- [Insight 5]\n\n' +
          '**RECOMMENDED ACTIONS:**\n' +
          '- [Action 1]\n' +
          '- [Action 2]\n' +
          '- [Action 3]\n' +
          '- [Action 4]\n' +
          '- [Action 5]\n\n' +
          '**FORMATTING RULES - CRITICAL:**\n' +
          '- ALWAYS use HTML <b> tags (NOT markdown **) to bold important text\n' +
          '- Do NOT use markdown ** syntax - use <b>text</b> instead\n' +
          '- Bold numbers: "score of <b>85</b>"\n' +
          '- Bold metrics: "win rate of <b>45%</b>"\n' +
          '- Bold comparisons: "<b>25 calls</b> this period"\n' +
          '- Bold field names: "Update the <b>Close Date</b> field"\n' +
          '- Bold percentages: "win rate of <b>50%</b>"\n' +
          '- Example: "Seller has <b>no activities</b> in the last <b>30 days</b>"\n\n'
      );

      promptParts.add('## KEY INSIGHTS GUIDANCE\n');
      promptParts.add(
        '**CRITICAL:** Always use "You" or "Your" when addressing the seller. NEVER use their name, "them", "they", "the seller", or generic pronouns. Speak directly TO the user.\n\n'
      );
      promptParts.add('Focus on:\n');
      promptParts.add(
        '- Activity patterns (high/low engagement) - use "You have..." or "Your activity..."\n'
      );
      promptParts.add(
        '- Pipeline momentum and risk factors - use "You have..." or "Your pipeline..."\n'
      );
      promptParts.add(
        '- Deal execution strengths and weaknesses - use "You closed..." or "Your win rate..."\n'
      );
      promptParts.add(
        '- Relationship building opportunities - use "You engaged..." or "Your contacts..."\n'
      );
      promptParts.add(
        '- Coaching recommendations - use "You should..." or "You need to..."\n\n'
      );

      promptParts.add('## RECOMMENDED ACTIONS GUIDANCE\n');
      promptParts.add(
        '**CRITICAL:** Always use "You" or "Your" when addressing the seller. NEVER use their name, "them", "they", "the seller", or generic pronouns. Speak directly TO the user.\n\n'
      );
      promptParts.add(
        'Provide specific, actionable recommendations with EXPLANATIONS:\n'
      );
      promptParts.add(
        '- "Focus on advancing <b>3 stagnant deals</b> because you have deals that haven\'t progressed in 30+ days"\n'
      );
      promptParts.add(
        '- "Schedule follow-up calls with <b>5 high-priority accounts</b> because you haven\'t engaged with key accounts recently"\n'
      );
      promptParts.add(
        '- "Increase activity volume to <b>50+ activities per week</b> because your current activity level is below target"\n'
      );
      promptParts.add(
        '- "Address <b>3 at-risk deals</b> with past-due close dates because you need to update close dates or close these deals"\n'
      );
      promptParts.add(
        '- "Leverage strong win rate of <b>50%</b> to replicate success patterns because you are performing well in deal execution"\n'
      );
      promptParts.add(
        '- "Build new relationships with <b>5+ new contacts</b> because you need to expand your network"\n'
      );
      promptParts.add(
        '\n**ALWAYS EXPLAIN WHY:** Every recommendation MUST include a "because" clause explaining the reasoning based on the metrics provided.\n\n'
      );

      String promptText = String.join(promptParts, '');

      // Create generate text request
      aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
      request.modelName = modelName;

      aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
      request.body = requestBody;
      requestBody.prompt = promptText;

      // Make request
      aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
      aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(
        request
      );

      // Extract the generated text from response
      if (response.Code200 != null && response.Code200.generation != null) {
        return response.Code200.generation.generatedText;
      } else {
        return 'No response received from Einstein AI. Please verify Einstein Generative AI is enabled in your org.';
      }
    } catch (aiplatform.ModelsAPI.createGenerations_ResponseException e) {
      System.debug(
        LoggingLevel.ERROR,
        'Models API Response Exception: ' + e.getMessage()
      );
      return 'Error analyzing seller performance: ' +
        e.getMessage() +
        '\n\nPlease ensure Einstein AI Models are enabled in Setup → Einstein Setup.';
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'Models API Error: ' + e.getMessage());
      return 'Unexpected error during AI analysis: ' +
        e.getMessage() +
        '\n\nPlease check debug logs for more details.';
    }
  }

  private static void parseAIResponse(
    String aiResponse,
    SellerPerformanceAnalysis analysis
  ) {
    if (String.isBlank(aiResponse)) {
      return;
    }

    // Parse trend
    Pattern trendPattern = Pattern.compile('\\*\\*TREND:\\*\\*\\s*([^\\n]+)');
    Matcher trendMatcher = trendPattern.matcher(aiResponse);
    if (trendMatcher.find()) {
      analysis.trend = cleanHtmlText(trendMatcher.group(1).trim());
    }

    // Parse key insights
    Pattern insightsPattern = Pattern.compile(
      '\\*\\*KEY INSIGHTS:\\*\\*\\s*\\n([\\s\\S]*?)\\n\\s*\\n\\s*\\*\\*RECOMMENDED ACTIONS'
    );
    Matcher insightsMatcher = insightsPattern.matcher(aiResponse);
    if (insightsMatcher.find()) {
      String insightsText = insightsMatcher.group(1);
      List<String> insights = new List<String>();
      for (String line : insightsText.split('\\n')) {
        line = line.trim();
        if (line.startsWith('-')) {
          insights.add(cleanHtmlText(line.substring(1).trim()));
        }
      }
      analysis.keyInsights = insights;
    }

    // Parse recommended actions
    Pattern actionsPattern = Pattern.compile(
      '\\*\\*RECOMMENDED ACTIONS:\\*\\*\\s*\\n([\\s\\S]*?)(?:\\n\\s*\\n|$)'
    );
    Matcher actionsMatcher = actionsPattern.matcher(aiResponse);
    if (actionsMatcher.find()) {
      String actionsText = actionsMatcher.group(1);
      List<String> actions = new List<String>();
      for (String line : actionsText.split('\\n')) {
        line = line.trim();
        if (line.startsWith('-')) {
          actions.add(cleanHtmlText(line.substring(1).trim()));
        }
      }
      analysis.recommendedActions = actions;
    }
  }

  // Helper method to clean HTML text - convert markdown to HTML and remove unwanted tags
  private static String cleanHtmlText(String text) {
    if (String.isBlank(text)) {
      return text;
    }

    // Convert markdown bold (**text**) to HTML bold (<b>text</b>)
    text = text.replaceAll('\\*\\*([^*]+)\\*\\*', '<b>$1</b>');

    // Remove any remaining markdown asterisks that weren't part of bold
    text = text.replaceAll('\\*([^*]+)\\*', '$1');

    return text;
  }

  // Helper class for sorting OpportunityFieldHistory by date
  private class HistoryDateComparator implements Comparator<OpportunityFieldHistory> {
    public Integer compare(
      OpportunityFieldHistory h1,
      OpportunityFieldHistory h2
    ) {
      if (h1.CreatedDate > h2.CreatedDate) {
        return 1;
      } else if (h1.CreatedDate < h2.CreatedDate) {
        return -1;
      }
      return 0;
    }
  }
}
