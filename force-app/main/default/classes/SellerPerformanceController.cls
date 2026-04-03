public with sharing class SellerPerformanceController {

  private static final String RT_ACCOUNT_STRATEGY = 'Account Strategy';
  private static final String RT_CUSTOM = 'Custom';
  private static final String RT_COHORT = 'Cohort';
  private static final String RT_HOME_INSTITUTION = 'Home Institution';

  @AuraEnabled(cacheable=false)
  public static SellerPerformanceAnalysis getSellerPerformance(Id userId) {
    SellerPerformanceAnalysis analysis = new SellerPerformanceAnalysis();

    try {
      List<User> userList = [
        SELECT Id, Name, Email, Profile.Name, UserRole.Name
        FROM User WHERE Id = :userId LIMIT 1
      ];
      if (userList.isEmpty()) {
        throw new AuraHandledException('User not found');
      }
      User currentUser = userList[0];

      SellerPerformanceMetrics metrics = gatherMetrics(userId);

      Integer[] categoryScores = calculatePerformanceScore(metrics);
      analysis.enrollmentScore = categoryScores[0];
      analysis.pipelineScore = categoryScores[1];
      analysis.partnershipScore = categoryScores[2];
      analysis.engagementScore = categoryScores[3];
      Integer totalScore = categoryScores[0] + categoryScores[1] +
        categoryScores[2] + categoryScores[3];
      totalScore = Math.min(100, Math.max(0, totalScore));
      analysis.score = totalScore;
      analysis.performanceStatus = getPerformanceStatus(totalScore);

      metrics.healthAssessmentTooltip = generateHealthAssessmentTooltip(
        totalScore, analysis.performanceStatus, metrics, categoryScores
      );

      String firstName = extractFirstName(currentUser.Name);
      String contextData = buildContextData(
        currentUser, metrics, totalScore, analysis.performanceStatus,
        firstName, categoryScores
      );

      String aiResponse = callEinsteinAI(
        contextData, totalScore, analysis.performanceStatus, firstName
      );
      parseAIResponse(aiResponse, analysis);

      metrics.trendTooltip = generateTrendTooltip(analysis.trend, metrics);
      analysis.metrics = metrics;

    } catch (Exception e) {
      System.debug('Error in getSellerPerformance: ' + e.getMessage());
      analysis.errorMessage = 'Unable to analyze performance: ' + e.getMessage();
      analysis.performanceStatus = 'Unknown';
      analysis.score = 0;
      analysis.keyInsights = new List<String>{ 'Error analyzing data. Please try again.' };
      analysis.recommendedActions = new List<String>{ 'Refresh to retry analysis.' };
    }
    return analysis;
  }

  // ───────────────────────────────────────────────────────────
  //  GATHER METRICS — CEA CAPA Education Cloud
  // ───────────────────────────────────────────────────────────
  private static SellerPerformanceMetrics gatherMetrics(Id userId) {
    SellerPerformanceMetrics m = new SellerPerformanceMetrics();
    Date cutoff30 = Date.today().addDays(-30);
    DateTime cutoff30DT = DateTime.newInstance(cutoff30.year(), cutoff30.month(), cutoff30.day());
    Date cutoff90 = Date.today().addDays(-90);
    DateTime cutoff90DT = DateTime.newInstance(cutoff90.year(), cutoff90.month(), cutoff90.day());
    Date cutoff365 = Date.today().addDays(-365);

    // ── 1. Enrollment Pacing (Account Strategy opps) ──
    gatherEnrollmentMetrics(userId, m);

    // ── 2. Program Pipeline (Custom + Cohort opps) ──
    gatherProgramPipelineMetrics(userId, m, cutoff365);

    // ── 3. Partnership Development ──
    gatherPartnershipMetrics(userId, m, cutoff90);

    // ── 4. Institutional Engagement ──
    gatherEngagementMetrics(userId, m, cutoff90DT);

    // ── 5. Sales Activity (calls / emails / meetings) ──
    gatherActivityMetrics(userId, m, cutoff30DT);

    // ── 6. Stage Movement (Custom + Cohort pipeline velocity) ──
    gatherStageMovementMetrics(userId, m, cutoff30DT);

    return m;
  }

  private static void gatherEnrollmentMetrics(Id userId, SellerPerformanceMetrics m) {
    Decimal totalForecasted = 0;
    Decimal totalActive = 0;
    Decimal totalForecastedRevenue = 0;
    Decimal totalProjectedRevenue = 0;
    Integer topInstitutionCount = 0;
    List<String> topInstitutions = new List<String>();

    try {
      List<AggregateResult> enrollAgg = [
        SELECT Account.Name acctName,
               SUM(Forecasted_Students__c) forecasted,
               SUM(Active_Enrollment__c) active,
               SUM(Forecasted_Revenue__c) fRev,
               SUM(ProjectedRevenue__c) pRev
        FROM Opportunity
        WHERE OwnerId = :userId
          AND RecordType.Name = :RT_ACCOUNT_STRATEGY
          AND StageName NOT IN ('Closed Lost', 'Closed Did Not Pursue',
                                'Closed Lost - Did Not Launch')
        GROUP BY Account.Name
        ORDER BY SUM(Forecasted_Students__c) DESC NULLS LAST
        LIMIT 50
      ];

      for (AggregateResult ar : enrollAgg) {
        Decimal f = ar.get('forecasted') != null ? (Decimal) ar.get('forecasted') : 0;
        Decimal a = ar.get('active') != null ? (Decimal) ar.get('active') : 0;
        Decimal fr = ar.get('fRev') != null ? (Decimal) ar.get('fRev') : 0;
        Decimal pr = ar.get('pRev') != null ? (Decimal) ar.get('pRev') : 0;
        totalForecasted += f;
        totalActive += a;
        totalForecastedRevenue += fr;
        totalProjectedRevenue += pr;

        if (f > 0 && topInstitutionCount < 5) {
          String name = (String) ar.get('acctName');
          if (String.isNotBlank(name)) {
            Decimal pacing = a > 0 && f > 0 ? (a / f * 100) : 0;
            topInstitutions.add(name + ': <b>' + a.setScale(0) + '/' + f.setScale(0) +
              '</b> (' + pacing.setScale(0) + '%)');
            topInstitutionCount++;
          }
        }
      }
    } catch (Exception e) {
      System.debug('Enrollment query error: ' + e.getMessage());
    }

    m.forecastedStudents = totalForecasted;
    m.activeEnrollment = totalActive;
    m.forecastedRevenue = totalForecastedRevenue;
    m.projectedRevenue = totalProjectedRevenue;
    m.enrollmentPacingPct = totalForecasted > 0
      ? (totalActive / totalForecasted * 100) : 0;

    // Apps started (IndividualApplication linked to user's institutions)
    try {
      Integer appCount = [
        SELECT COUNT()
        FROM IndividualApplication
        WHERE Account.OwnerId = :userId
          AND CreatedDate = THIS_FISCAL_QUARTER
      ];
      m.appsStarted = appCount;
    } catch (Exception e) {
      System.debug('IndividualApplication query error: ' + e.getMessage());
      m.appsStarted = 0;
    }

    // Build tooltips
    m.forecastedStudentsTooltip =
      'Forecasted Students: <b>' + totalForecasted.setScale(0) + '</b><br/>' +
      'Active Enrollment: <b>' + totalActive.setScale(0) + '</b><br/>' +
      'Pacing: <b>' + m.enrollmentPacingPct.setScale(1) + '%</b><br/>' +
      (topInstitutions.isEmpty() ? '' :
        '<br/>Top Institutions:<br/>' + String.join(topInstitutions, '<br/>'));

    m.activeEnrollmentTooltip =
      'Active Students: <b>' + totalActive.setScale(0) + '</b><br/>' +
      'Apps Started (This Quarter): <b>' + m.appsStarted + '</b><br/>' +
      'Forecasted Revenue: <b>' + formatCurrency(totalForecastedRevenue) + '</b>';

    m.enrollmentPacingTooltip =
      'Enrollment Pacing: <b>' + m.enrollmentPacingPct.setScale(1) + '%</b><br/>' +
      'Active: <b>' + totalActive.setScale(0) + '</b> of <b>' +
      totalForecasted.setScale(0) + '</b> forecasted<br/>' +
      'Gap: <b>' + (totalForecasted - totalActive).setScale(0) + '</b> students remaining';
  }

  private static void gatherProgramPipelineMetrics(
    Id userId, SellerPerformanceMetrics m, Date cutoff365
  ) {
    Integer openCustom = 0;
    Integer openCohort = 0;
    Integer won = 0;
    Integer lost = 0;
    Integer dnp = 0;
    Integer stagnant = 0;
    Integer inDev = 0;
    Integer proposalSent = 0;
    Integer newStage = 0;
    Map<String, Integer> stageCounts = new Map<String, Integer>();

    try {
      List<Opportunity> programOpps = [
        SELECT Id, Name, StageName, RecordType.Name, LastModifiedDate,
               CreatedDate, Account.Name, IsClosed, IsWon
        FROM Opportunity
        WHERE OwnerId = :userId
          AND RecordType.Name IN (:RT_CUSTOM, :RT_COHORT)
          AND (CreatedDate >= :cutoff365 OR IsClosed = false)
        ORDER BY CreatedDate DESC
        LIMIT 500
      ];

      for (Opportunity opp : programOpps) {
        String rt = opp.RecordType.Name;
        String stage = opp.StageName;

        if (!opp.IsClosed) {
          if (rt == RT_CUSTOM) openCustom++;
          if (rt == RT_COHORT) openCohort++;

          if (stage == 'In Development') inDev++;
          else if (stage == 'Proposal Sent' || stage == 'Proposal Sent to University') proposalSent++;
          else if (stage == 'New') newStage++;

          // Stagnant = no modification in 30+ days
          if (opp.LastModifiedDate < DateTime.now().addDays(-30)) {
            stagnant++;
          }
        } else if (opp.IsWon) {
          won++;
        } else {
          if (stage == 'Closed Did Not Pursue') dnp++;
          else lost++;
        }

        Integer c = stageCounts.containsKey(stage) ? stageCounts.get(stage) : 0;
        stageCounts.put(stage, c + 1);
      }
    } catch (Exception e) {
      System.debug('Program pipeline query error: ' + e.getMessage());
    }

    m.openCustomPrograms = openCustom;
    m.openCohortPrograms = openCohort;
    m.programsWon = won;
    m.programsLost = lost;
    m.programsDNP = dnp;
    m.stagnantPrograms = stagnant;
    m.programsInDevelopment = inDev;
    m.programsProposalSent = proposalSent;
    m.programsNew = newStage;

    Integer totalDecided = won + lost + dnp;
    m.customProgramWinRate = totalDecided > 0
      ? (Decimal.valueOf(won) / Decimal.valueOf(totalDecided) * 100) : 0;

    // Build stage breakdown for tooltip
    String stageBreakdown = '';
    for (String stage : stageCounts.keySet()) {
      if (String.isNotBlank(stageBreakdown)) stageBreakdown += '<br/>';
      stageBreakdown += stage + ': <b>' + stageCounts.get(stage) + '</b>';
    }

    m.openProgramsTooltip =
      'Open Custom Programs: <b>' + openCustom + '</b><br/>' +
      'Open Cohort Programs: <b>' + openCohort + '</b><br/>' +
      'In Development: <b>' + inDev + '</b><br/>' +
      'Proposal Sent: <b>' + proposalSent + '</b><br/>' +
      'Stagnant (30+ days): <b>' + stagnant + '</b>';

    m.programsWonTooltip =
      'Programs Won: <b>' + won + '</b><br/>' +
      'Programs Lost: <b>' + lost + '</b><br/>' +
      'Did Not Pursue: <b>' + dnp + '</b><br/>' +
      'Win Rate: <b>' + m.customProgramWinRate.setScale(1) + '%</b>';

    m.pipelineStageTooltip =
      'Program Pipeline by Stage:<br/>' + stageBreakdown;
  }

  private static void gatherPartnershipMetrics(
    Id userId, SellerPerformanceMetrics m, Date cutoff90
  ) {
    Integer activeStrategies = 0;
    Integer proposals = 0;
    Integer agreements = 0;
    Integer newAgreements = 0;
    Decimal totalPricePerStudent = 0;
    Integer priceCount = 0;
    Decimal totalMargin = 0;
    Integer marginCount = 0;

    try {
      List<Opportunity> strategyOpps = [
        SELECT Id, StageName, Date_Proposal_Sent__c, Date_Agreement_Signed__c,
               ActivePricePerStudent__c, ActiveMargin__c, CreatedDate
        FROM Opportunity
        WHERE OwnerId = :userId
          AND RecordType.Name = :RT_ACCOUNT_STRATEGY
          AND StageName NOT IN ('Closed Lost', 'Closed Did Not Pursue',
                                'Closed Lost - Did Not Launch', 'Closed Won Archive')
        LIMIT 2000
      ];

      for (Opportunity opp : strategyOpps) {
        if (opp.StageName != 'Closed Won') {
          activeStrategies++;
        }

        if (opp.Date_Proposal_Sent__c != null && opp.Date_Proposal_Sent__c >= cutoff90) {
          proposals++;
        }
        if (opp.Date_Agreement_Signed__c != null && opp.Date_Agreement_Signed__c >= cutoff90) {
          agreements++;
        }
        if (opp.CreatedDate.date() >= cutoff90) {
          newAgreements++;
        }
        if (opp.ActivePricePerStudent__c != null && opp.ActivePricePerStudent__c > 0) {
          totalPricePerStudent += opp.ActivePricePerStudent__c;
          priceCount++;
        }
        if (opp.ActiveMargin__c != null) {
          totalMargin += opp.ActiveMargin__c;
          marginCount++;
        }
      }
    } catch (Exception e) {
      System.debug('Partnership query error: ' + e.getMessage());
    }

    m.activeAccountStrategies = activeStrategies;
    m.proposalsSent = proposals;
    m.agreementsSigned = agreements;
    m.newAgreementsThisTerm = newAgreements;
    m.revenuePerStudent = priceCount > 0 ? (totalPricePerStudent / priceCount) : 0;
    m.avgMargin = marginCount > 0 ? (totalMargin / marginCount) : 0;

    m.proposalsSentTooltip =
      'Proposals Sent (90d): <b>' + proposals + '</b><br/>' +
      'Agreements Signed (90d): <b>' + agreements + '</b><br/>' +
      'New This Term: <b>' + newAgreements + '</b><br/>' +
      'Active Strategies: <b>' + activeStrategies + '</b>';

    m.projectedRevenueTooltip =
      'Projected Revenue: <b>' + formatCurrency(m.projectedRevenue) + '</b><br/>' +
      'Forecasted Revenue: <b>' + formatCurrency(m.forecastedRevenue) + '</b><br/>' +
      'Avg Price/Student: <b>' + formatCurrency(m.revenuePerStudent) + '</b><br/>' +
      'Avg Margin: <b>' + (m.avgMargin != null ? m.avgMargin.setScale(1) + '%' : 'N/A') + '</b>';
  }

  private static void gatherEngagementMetrics(
    Id userId, SellerPerformanceMetrics m, DateTime cutoff90DT
  ) {
    // Success Plans
    try {
      m.successPlansActive = [
        SELECT COUNT() FROM Success_Plan__c WHERE OwnerId = :userId
      ];
    } catch (Exception e) {
      System.debug('Success Plan query error: ' + e.getMessage());
    }

    // RFPs in last 90 days
    try {
      m.rfpsSubmitted = [
        SELECT COUNT() FROM Request_For_Proposal__c
        WHERE OwnerId = :userId AND CreatedDate >= :cutoff90DT
      ];
    } catch (Exception e) {
      System.debug('RFP query error: ' + e.getMessage());
    }

    // Opportunity Groups
    try {
      m.opportunityGroups = [
        SELECT COUNT() FROM Opportunity_Group__c WHERE OwnerId = :userId
      ];
    } catch (Exception e) {
      System.debug('Opp Group query error: ' + e.getMessage());
    }

    // Home Institutions managed
    try {
      m.homeInstitutionsManaged = [
        SELECT COUNT() FROM Account
        WHERE OwnerId = :userId AND RecordType.Name = :RT_HOME_INSTITUTION
      ];
    } catch (Exception e) {
      System.debug('Home Institution query error: ' + e.getMessage());
    }

    // IR Meetings (last 90 days)
    try {
      m.irMeetings = [
        SELECT COUNT() FROM Event
        WHERE OwnerId = :userId AND CreatedDate >= :cutoff90DT
          AND RecordType.Name = 'IR Meeting'
      ];
    } catch (Exception e) {
      System.debug('IR Meeting query error: ' + e.getMessage());
    }

    m.successPlansTooltip =
      'Success Plans: <b>' + m.successPlansActive + '</b><br/>' +
      'RFPs Submitted (90d): <b>' + m.rfpsSubmitted + '</b><br/>' +
      'Opportunity Groups: <b>' + m.opportunityGroups + '</b>';

    m.institutionsTooltip =
      'Home Institutions: <b>' + m.homeInstitutionsManaged + '</b><br/>' +
      'IR Meetings (90d): <b>' + m.irMeetings + '</b>';
  }

  // ───────────────────────────────────────────────────────────
  //  SALES ACTIVITY — Revenue.io calls + Tasks + Events
  // ───────────────────────────────────────────────────────────
  private static void gatherActivityMetrics(
    Id userId, SellerPerformanceMetrics m, DateTime cutoff30DT
  ) {
    Integer callsMade = 0;
    Integer callsInbound = 0;
    Integer callsConnected = 0;
    Decimal totalCallSecs = 0;
    Integer emailsSent = 0;
    Integer tasksCompleted = 0;

    try {
      List<Task> tasks = [
        SELECT Id, Subject, TaskSubtype, Status, CallType,
               CallDurationInSeconds, CallDisposition
        FROM Task
        WHERE OwnerId = :userId AND CreatedDate >= :cutoff30DT
      ];

      for (Task t : tasks) {
        String subj = t.Subject != null ? t.Subject.toLowerCase() : '';
        Boolean isCall = (t.TaskSubtype == 'Call')
          || subj.contains('phone call')
          || subj.contains('call out')
          || subj.contains('call in')
          || subj.contains('outbound call')
          || subj.contains('inbound call');
        Boolean isEmail = (t.TaskSubtype == 'Email')
          || subj.contains('email')
          || subj.contains('email sent');

        if (isCall) {
          if (t.CallType == 'Inbound' || subj.contains('call in') || subj.contains('inbound')) {
            callsInbound++;
          } else {
            callsMade++;
          }
          if (t.CallDurationInSeconds != null && t.CallDurationInSeconds > 0) {
            callsConnected++;
            totalCallSecs += t.CallDurationInSeconds;
          }
        } else if (isEmail) {
          emailsSent++;
        }

        if (t.Status == 'Completed') {
          tasksCompleted++;
        }
      }
    } catch (Exception e) {
      System.debug('Activity (Task) query error: ' + e.getMessage());
    }

    Integer meetingsHeld = 0;
    try {
      meetingsHeld = [
        SELECT COUNT() FROM Event
        WHERE OwnerId = :userId AND CreatedDate >= :cutoff30DT
          AND StartDateTime <= :DateTime.now()
      ];
    } catch (Exception e) {
      System.debug('Activity (Event) query error: ' + e.getMessage());
    }

    m.callsMade = callsMade;
    m.callsInbound = callsInbound;
    m.callsConnected = callsConnected;
    m.totalTalkTimeMins = totalCallSecs > 0 ? (totalCallSecs / 60).setScale(1) : 0;
    m.emailsSent = emailsSent;
    m.meetingsHeld = meetingsHeld;
    m.tasksCompleted = tasksCompleted;

    Integer totalCalls = callsMade + callsInbound;
    Decimal connRate = totalCalls > 0
      ? (Decimal.valueOf(callsConnected) / Decimal.valueOf(totalCalls) * 100).setScale(1)
      : 0;
    Decimal avgTalkTime = callsConnected > 0
      ? (m.totalTalkTimeMins / callsConnected).setScale(1)
      : 0;

    // Legacy shared tooltips (kept for AI context)
    m.callsTooltip =
      'Outbound: <b>' + callsMade + '</b>  ·  Inbound: <b>' + callsInbound + '</b><br/>' +
      'Connected: <b>' + callsConnected + '</b>  ·  Rate: <b>' + connRate + '%</b><br/>' +
      'Avg Talk: <b>' + avgTalkTime + ' min</b>  ·  Total: <b>' + m.totalTalkTimeMins + ' min</b>';

    m.activityTooltip =
      'Calls Made: <b>' + callsMade + '</b><br/>' +
      'Calls Received: <b>' + callsInbound + '</b><br/>' +
      'Emails Sent: <b>' + emailsSent + '</b><br/>' +
      'Meetings Held: <b>' + meetingsHeld + '</b><br/>' +
      'Tasks Completed: <b>' + tasksCompleted + '</b><br/>' +
      'Total Talk Time: <b>' + m.totalTalkTimeMins + ' min</b>';

    // Per-card focused tooltips
    m.callsMadeTooltip =
      'Outbound Calls: <b>' + callsMade + '</b><br/>' +
      'Inbound Calls: <b>' + callsInbound + '</b><br/>' +
      'Total Calls: <b>' + totalCalls + '</b><br/>' +
      'Connected: <b>' + callsConnected + '</b><br/>' +
      'Connection Rate: <b>' + connRate + '%</b>';

    m.callsConnectedTooltip =
      'Connected Calls: <b>' + callsConnected + '</b> of <b>' + totalCalls + '</b><br/>' +
      'Connection Rate: <b>' + connRate + '%</b><br/>' +
      'Avg Talk Time: <b>' + avgTalkTime + ' min</b><br/>' +
      'Total Talk Time: <b>' + m.totalTalkTimeMins + ' min</b>';

    m.talkTimeTooltip =
      'Total Talk Time: <b>' + m.totalTalkTimeMins + ' min</b><br/>' +
      'Connected Calls: <b>' + callsConnected + '</b><br/>' +
      'Avg Per Call: <b>' + avgTalkTime + ' min</b><br/>' +
      'Outbound Calls: <b>' + callsMade + '</b>';

    m.emailsSentTooltip =
      'Emails Sent: <b>' + emailsSent + '</b><br/>' +
      'Period: <b>Last 30 days</b><br/>' +
      'Source: <b>Salesforce Tasks (Email subtype)</b>';

    m.meetingsTooltip =
      'Meetings Held: <b>' + meetingsHeld + '</b><br/>' +
      'Period: <b>Last 30 days</b><br/>' +
      'Source: <b>Salesforce Events</b>';

    m.tasksDoneTooltip =
      'Tasks Completed: <b>' + tasksCompleted + '</b><br/>' +
      'Period: <b>Last 30 days</b><br/>' +
      'Calls Made: <b>' + callsMade + '</b><br/>' +
      'Emails Sent: <b>' + emailsSent + '</b>';
  }

  // ───────────────────────────────────────────────────────────
  //  STAGE MOVEMENT — Custom + Cohort opportunity pipeline
  // ───────────────────────────────────────────────────────────
  private static void gatherStageMovementMetrics(
    Id userId, SellerPerformanceMetrics m, DateTime cutoff30DT
  ) {
    // Current open stage distribution
    Integer stageNew = 0;
    Integer stageInDev = 0;
    Integer stageProposal = 0;
    Integer stageQualified = 0;
    Integer stageAgreement = 0;
    Integer stageRoster = 0;
    Integer stageOnSite = 0;
    Set<Id> oppIds = new Set<Id>();

    try {
      List<Opportunity> programOpps = [
        SELECT Id, StageName
        FROM Opportunity
        WHERE OwnerId = :userId
          AND RecordType.Name IN ('Custom', 'Cohort')
          AND IsClosed = false
      ];

      for (Opportunity opp : programOpps) {
        oppIds.add(opp.Id);
        String stage = opp.StageName;
        if (stage == 'New') stageNew++;
        else if (stage == 'In Development') stageInDev++;
        else if (stage == 'Proposal Sent' || stage == 'Proposal Sent to University') stageProposal++;
        else if (stage == 'Qualified') stageQualified++;
        else if (stage == 'Agreement Signed') stageAgreement++;
        else if (stage == 'Roster Received') stageRoster++;
        else if (stage == 'Program Onsite') stageOnSite++;
      }
    } catch (Exception e) {
      System.debug('Stage distribution query error: ' + e.getMessage());
    }

    m.stageNewCount = stageNew;
    m.stageInDevCount = stageInDev;
    m.stageProposalCount = stageProposal;
    m.stageQualifiedCount = stageQualified;
    m.stageAgreementCount = stageAgreement;
    m.stageRosterCount = stageRoster;
    m.stageOnSiteCount = stageOnSite;

    // Stage changes in last 30 days on Custom + Cohort opps
    Integer advancing = 0;
    Map<String, Integer> movementMap = new Map<String, Integer>();

    if (!oppIds.isEmpty()) {
      try {
        List<OpportunityFieldHistory> history = [
          SELECT OpportunityId, OldValue, NewValue, CreatedDate
          FROM OpportunityFieldHistory
          WHERE OpportunityId IN :oppIds
            AND Field = 'StageName'
            AND CreatedDate >= :cutoff30DT
          ORDER BY CreatedDate DESC
        ];

        Set<Id> movedOpps = new Set<Id>();
        for (OpportunityFieldHistory h : history) {
          movedOpps.add(h.OpportunityId);
          String mv = (String) h.OldValue + ' → ' + (String) h.NewValue;
          Integer cnt = movementMap.containsKey(mv) ? movementMap.get(mv) : 0;
          movementMap.put(mv, cnt + 1);
        }
        advancing = movedOpps.size();
      } catch (Exception e) {
        System.debug('Stage history query error: ' + e.getMessage());
      }
    }

    m.dealsAdvancingCount = advancing;

    String mvBreakdown = '';
    for (String mv : movementMap.keySet()) {
      if (String.isNotBlank(mvBreakdown)) mvBreakdown += '<br/>';
      mvBreakdown += mv + ': <b>' + movementMap.get(mv) + '</b>';
    }

    m.stageMovementTooltip =
      'Deals Moving Stages (30d): <b>' + advancing + '</b><br/>' +
      'New: <b>' + stageNew + '</b><br/>' +
      'In Development: <b>' + stageInDev + '</b><br/>' +
      'Proposal Sent: <b>' + stageProposal + '</b><br/>' +
      'Qualified: <b>' + stageQualified + '</b><br/>' +
      'Agreement Signed: <b>' + stageAgreement + '</b><br/>' +
      'Roster Received: <b>' + stageRoster + '</b>' +
      (String.isNotBlank(mvBreakdown) ? '<br/><br/>Recent Movements:<br/>' + mvBreakdown : '');
  }

  // ───────────────────────────────────────────────────────────
  //  SCORING — four categories totalling 100
  // ───────────────────────────────────────────────────────────
  private static Integer[] calculatePerformanceScore(SellerPerformanceMetrics m) {
    Integer enrollment = 0;   // max 30
    Integer pipeline   = 0;   // max 25
    Integer partnership = 0;  // max 25
    Integer engagement  = 0;  // max 20

    // ── Enrollment Pacing (30 pts) ──
    // Pacing % (15 pts)
    Decimal pacing = m.enrollmentPacingPct != null ? m.enrollmentPacingPct : 0;
    if (pacing >= 100) enrollment += 15;
    else if (pacing >= 80) enrollment += 12;
    else if (pacing >= 60) enrollment += 9;
    else if (pacing >= 40) enrollment += 6;
    else if (pacing > 0) enrollment += 3;

    // Apps started (10 pts)
    Integer apps = m.appsStarted != null ? m.appsStarted : 0;
    if (apps >= 50) enrollment += 10;
    else if (apps >= 30) enrollment += 8;
    else if (apps >= 15) enrollment += 6;
    else if (apps >= 5) enrollment += 4;
    else if (apps > 0) enrollment += 2;

    // Forecasted revenue presence (5 pts)
    Decimal fRev = m.forecastedRevenue != null ? m.forecastedRevenue : 0;
    if (fRev >= 500000) enrollment += 5;
    else if (fRev >= 200000) enrollment += 4;
    else if (fRev >= 50000) enrollment += 3;
    else if (fRev > 0) enrollment += 1;

    // ── Program Pipeline (25 pts) ──
    // Open programs in active stages (8 pts)
    Integer openPrograms = safeInt(m.openCustomPrograms) + safeInt(m.openCohortPrograms);
    if (openPrograms >= 10) pipeline += 8;
    else if (openPrograms >= 5) pipeline += 6;
    else if (openPrograms >= 3) pipeline += 5;
    else if (openPrograms >= 1) pipeline += 3;

    // Win rate (7 pts)
    Decimal winRate = m.customProgramWinRate != null ? m.customProgramWinRate : 0;
    if (winRate >= 50) pipeline += 7;
    else if (winRate >= 35) pipeline += 5;
    else if (winRate >= 20) pipeline += 3;
    else if (winRate > 0) pipeline += 1;

    // Programs won (5 pts)
    Integer won = safeInt(m.programsWon);
    if (won >= 10) pipeline += 5;
    else if (won >= 5) pipeline += 4;
    else if (won >= 2) pipeline += 3;
    else if (won >= 1) pipeline += 2;

    // Stagnant penalty (5 pts, inverse)
    Integer stagnant = safeInt(m.stagnantPrograms);
    if (stagnant == 0) pipeline += 5;
    else if (stagnant <= 2) pipeline += 3;
    else if (stagnant <= 5) pipeline += 1;
    else pipeline -= 2;

    // ── Partnership Development (25 pts) ──
    // Proposals sent (8 pts)
    Integer props = safeInt(m.proposalsSent);
    if (props >= 5) partnership += 8;
    else if (props >= 3) partnership += 6;
    else if (props >= 1) partnership += 4;

    // Agreements signed (7 pts)
    Integer agreements = safeInt(m.agreementsSigned);
    if (agreements >= 5) partnership += 7;
    else if (agreements >= 3) partnership += 5;
    else if (agreements >= 1) partnership += 3;

    // Revenue per student (5 pts)
    Decimal rps = m.revenuePerStudent != null ? m.revenuePerStudent : 0;
    if (rps >= 10000) partnership += 5;
    else if (rps >= 5000) partnership += 4;
    else if (rps >= 2000) partnership += 3;
    else if (rps > 0) partnership += 1;

    // Margin health (5 pts)
    Decimal margin = m.avgMargin != null ? m.avgMargin : 0;
    if (margin >= 30) partnership += 5;
    else if (margin >= 20) partnership += 4;
    else if (margin >= 10) partnership += 3;
    else if (margin > 0) partnership += 1;

    // ── Institutional Engagement (20 pts) ──
    // Success Plans (6 pts)
    Integer sp = safeInt(m.successPlansActive);
    if (sp >= 5) engagement += 6;
    else if (sp >= 3) engagement += 5;
    else if (sp >= 1) engagement += 3;

    // RFPs submitted (5 pts)
    Integer rfps = safeInt(m.rfpsSubmitted);
    if (rfps >= 5) engagement += 5;
    else if (rfps >= 3) engagement += 4;
    else if (rfps >= 1) engagement += 3;

    // Opportunity Groups (4 pts)
    Integer og = safeInt(m.opportunityGroups);
    if (og >= 5) engagement += 4;
    else if (og >= 3) engagement += 3;
    else if (og >= 1) engagement += 2;

    // Home Institutions managed (3 pts)
    Integer hi = safeInt(m.homeInstitutionsManaged);
    if (hi >= 50) engagement += 3;
    else if (hi >= 20) engagement += 2;
    else if (hi > 0) engagement += 1;

    // IR Meetings (2 pts)
    Integer meetings = safeInt(m.irMeetings);
    if (meetings >= 3) engagement += 2;
    else if (meetings >= 1) engagement += 1;

    return new Integer[]{ enrollment, pipeline, partnership, engagement };
  }

  private static Integer safeInt(Integer val) {
    return val != null ? val : 0;
  }

  private static String getPerformanceStatus(Integer score) {
    if (score >= 80) return 'Crushing It';
    if (score >= 60) return 'On Target';
    if (score >= 40) return 'Needs Attention';
    return 'Struggling';
  }

  // ───────────────────────────────────────────────────────────
  //  TOOLTIPS
  // ───────────────────────────────────────────────────────────
  private static String generateHealthAssessmentTooltip(
    Integer score, String status, SellerPerformanceMetrics m, Integer[] cats
  ) {
    String t = 'Your score of <b>' + score + '</b> is ';
    String targetRange = '';

    if (status == 'Crushing It') {
      targetRange = '80+';
      t += 'above target (<b>' + targetRange + '</b>). Excellent work!<br/><br/>';
    } else if (status == 'On Target') {
      targetRange = '60-79';
      t += 'within target (<b>' + targetRange + '</b>). Great job!<br/><br/>';
    } else if (status == 'Needs Attention') {
      targetRange = '40-59';
      t += 'below target (<b>60+</b>). Focus on the areas below.<br/><br/>';
    } else {
      targetRange = 'below 40';
      t += 'significantly below target. Urgent improvements needed.<br/><br/>';
    }

    t += '<b>Score Breakdown:</b><br/>';
    t += 'Enrollment Pacing: <b>' + cats[0] + '/30</b><br/>';
    t += 'Program Pipeline: <b>' + cats[1] + '/25</b><br/>';
    t += 'Partnership Development: <b>' + cats[2] + '/25</b><br/>';
    t += 'Institutional Engagement: <b>' + cats[3] + '/20</b><br/><br/>';

    t += '<b>How to improve:</b><br/>';
    if (cats[0] < 20) {
      t += '• Boost enrollment pacing — follow up with under-pacing institutions<br/>';
    }
    if (cats[1] < 15) {
      t += '• Advance stagnant programs through the pipeline<br/>';
    }
    if (cats[2] < 15) {
      t += '• Send more proposals and close pending agreements<br/>';
    }
    if (cats[3] < 12) {
      t += '• Create success plans and submit RFPs for key accounts<br/>';
    }
    return t;
  }

  private static String generateTrendTooltip(String trend, SellerPerformanceMetrics m) {
    String dir = 'Steady';
    if (String.isNotBlank(trend)) {
      if (trend.toLowerCase().contains('accelerating')) dir = 'Accelerating';
      else if (trend.toLowerCase().contains('declining')) dir = 'Declining';
    }

    String t = 'Your trend is <b>' + dir + '</b>.<br/><br/>';
    t += '<b>Key Indicators:</b><br/>';
    t += 'Enrollment Pacing: <b>' + (m.enrollmentPacingPct != null ? m.enrollmentPacingPct.setScale(1) : 0) + '%</b><br/>';
    t += 'Open Programs: <b>' + (safeInt(m.openCustomPrograms) + safeInt(m.openCohortPrograms)) + '</b><br/>';
    t += 'Programs Won: <b>' + safeInt(m.programsWon) + '</b><br/>';
    t += 'Stagnant Programs: <b>' + safeInt(m.stagnantPrograms) + '</b><br/>';
    t += 'Proposals Sent: <b>' + safeInt(m.proposalsSent) + '</b><br/>';
    t += 'Success Plans: <b>' + safeInt(m.successPlansActive) + '</b>';
    return t;
  }

  // ───────────────────────────────────────────────────────────
  //  AI CONTEXT + CALL
  // ───────────────────────────────────────────────────────────
  private static String extractFirstName(String fullName) {
    if (String.isBlank(fullName)) return 'the rep';
    List<String> parts = fullName.split(' ', 2);
    return (parts.size() > 0 && String.isNotBlank(parts[0])) ? parts[0] : 'the rep';
  }

  private static String buildContextData(
    User u, SellerPerformanceMetrics m, Integer score, String status,
    String firstName, Integer[] cats
  ) {
    List<String> ctx = new List<String>();

    ctx.add('## CEA CAPA SELLER PERFORMANCE ANALYSIS\n\n');
    ctx.add('**Context:** CEA CAPA Education Abroad — a study abroad provider. ');
    ctx.add('Sellers (Institutional Relations reps) manage university partnerships, ');
    ctx.add('develop custom study abroad programs, and drive student enrollment.\n\n');
    ctx.add('**Date:** ' + Date.today().format() + '\n\n');

    ctx.add('### Seller Details\n');
    ctx.add('- **Name:** ' + u.Name + ' (' + firstName + ')\n');
    ctx.add('- **Profile:** ' + (u.Profile != null ? u.Profile.Name : 'Unknown') + '\n');
    ctx.add('- **Role:** ' + (u.UserRole != null ? u.UserRole.Name : 'Not assigned') + '\n\n');

    ctx.add('### Enrollment Pacing (Score: ' + cats[0] + '/30)\n');
    ctx.add('- **Forecasted Students:** ' + m.forecastedStudents.setScale(0) + '\n');
    ctx.add('- **Active Enrollment:** ' + m.activeEnrollment.setScale(0) + '\n');
    ctx.add('- **Enrollment Pacing:** ' + m.enrollmentPacingPct.setScale(1) + '%\n');
    ctx.add('- **Apps Started (Quarter):** ' + m.appsStarted + '\n');
    ctx.add('- **Forecasted Revenue:** $' + formatCurrency(m.forecastedRevenue) + '\n');
    ctx.add('- **Projected Revenue:** $' + formatCurrency(m.projectedRevenue) + '\n\n');

    ctx.add('### Program Pipeline (Score: ' + cats[1] + '/25)\n');
    ctx.add('- **Open Custom Programs:** ' + m.openCustomPrograms + '\n');
    ctx.add('- **Open Cohort Programs:** ' + m.openCohortPrograms + '\n');
    ctx.add('- **Programs Won (12mo):** ' + m.programsWon + '\n');
    ctx.add('- **Programs Lost:** ' + m.programsLost + '\n');
    ctx.add('- **Did Not Pursue:** ' + m.programsDNP + '\n');
    ctx.add('- **Win Rate:** ' + m.customProgramWinRate.setScale(1) + '%\n');
    ctx.add('- **Stagnant Programs (30d+):** ' + m.stagnantPrograms + '\n');
    ctx.add('- **In Development:** ' + m.programsInDevelopment + '\n');
    ctx.add('- **Proposals Pending:** ' + m.programsProposalSent + '\n\n');

    ctx.add('### Partnership Development (Score: ' + cats[2] + '/25)\n');
    ctx.add('- **Active Account Strategies:** ' + m.activeAccountStrategies + '\n');
    ctx.add('- **Proposals Sent (90d):** ' + m.proposalsSent + '\n');
    ctx.add('- **Agreements Signed (90d):** ' + m.agreementsSigned + '\n');
    ctx.add('- **Avg Revenue/Student:** $' + formatCurrency(m.revenuePerStudent) + '\n');
    ctx.add('- **Avg Margin:** ' + m.avgMargin.setScale(1) + '%\n\n');

    ctx.add('### Institutional Engagement (Score: ' + cats[3] + '/20)\n');
    ctx.add('- **Success Plans Active:** ' + m.successPlansActive + '\n');
    ctx.add('- **RFPs Submitted (90d):** ' + m.rfpsSubmitted + '\n');
    ctx.add('- **Opportunity Groups:** ' + m.opportunityGroups + '\n');
    ctx.add('- **Home Institutions Managed:** ' + m.homeInstitutionsManaged + '\n');
    ctx.add('- **IR Meetings (90d):** ' + m.irMeetings + '\n\n');

    ctx.add('### Sales Activity (Last 30 Days — via Revenue.io / Salesforce Tasks & Events)\n');
    ctx.add('- **Outbound Calls Made:** ' + m.callsMade + '\n');
    ctx.add('- **Inbound Calls Received:** ' + m.callsInbound + '\n');
    ctx.add('- **Calls Connected:** ' + m.callsConnected + '\n');
    ctx.add('- **Total Talk Time:** ' + m.totalTalkTimeMins + ' min\n');
    ctx.add('- **Emails Sent:** ' + m.emailsSent + '\n');
    ctx.add('- **Meetings Held:** ' + m.meetingsHeld + '\n');
    ctx.add('- **Tasks Completed:** ' + m.tasksCompleted + '\n\n');

    ctx.add('### Pipeline Stage Movement (Custom + Cohort Opps, Last 30 Days)\n');
    ctx.add('- **Deals Moving Stages (30d):** ' + m.dealsAdvancingCount + '\n');
    ctx.add('- **Current Stage — New:** ' + m.stageNewCount + '\n');
    ctx.add('- **Current Stage — In Development:** ' + m.stageInDevCount + '\n');
    ctx.add('- **Current Stage — Proposal Sent:** ' + m.stageProposalCount + '\n');
    ctx.add('- **Current Stage — Qualified:** ' + m.stageQualifiedCount + '\n');
    ctx.add('- **Current Stage — Agreement Signed:** ' + m.stageAgreementCount + '\n');
    ctx.add('- **Current Stage — Roster Received:** ' + m.stageRosterCount + '\n\n');

    ctx.add('## CALCULATED PERFORMANCE SCORE: ' + score + '/100 (' + status + ')\n\n');
    ctx.add('**Do NOT recalculate this score. Accept it as final.**\n\n');

    return String.join(ctx, '');
  }

  private static String callEinsteinAI(
    String contextData, Integer score, String status, String firstName
  ) {
    try {
      String modelName = 'sfdc_ai__DefaultOpenAIGPT4OmniMini';
      List<String> parts = new List<String>();

      parts.add(contextData);
      parts.add('## YOUR TASK\n\n');
      parts.add('You are analyzing a CEA CAPA Education Abroad Institutional Relations representative\'s performance. ');
      parts.add('Based on the score (' + score + '/100), status (' + status + '), and metrics, generate:\n');
      parts.add('1. A trend analysis (Accelerating, Steady, or Declining)\n');
      parts.add('2. 5 key insights about their study abroad business development performance\n');
      parts.add('3. 5 specific, actionable recommendations\n\n');

      parts.add('## DOMAIN CONTEXT\n\n');
      parts.add('CEA CAPA sells study abroad programs to U.S. universities. Key concepts:\n');
      parts.add('- **Account Strategy** = institutional partnership agreement per term with a university\n');
      parts.add('- **Custom Program** = faculty-led study abroad trip (the active sales pipeline)\n');
      parts.add('- **Cohort** = group program offering\n');
      parts.add('- **Home Institution** = the U.S. university partner\n');
      parts.add('- **Enrollment Pacing** = forecasted vs actual student enrollment (the #1 KPI)\n');
      parts.add('- **Success Plan** = strategic engagement plan for a key institution\n');
      parts.add('- **RFP** = Request for Proposal for a custom program\n\n');

      parts.add('## OUTPUT FORMAT\n\n');
      parts.add('**TREND:** [Accelerating|Steady|Declining]\n\n');
      parts.add('**KEY INSIGHTS:**\n- [Insight 1]\n- [Insight 2]\n- [Insight 3]\n- [Insight 4]\n- [Insight 5]\n\n');
      parts.add('**RECOMMENDED ACTIONS:**\n- [Action 1]\n- [Action 2]\n- [Action 3]\n- [Action 4]\n- [Action 5]\n\n');

      parts.add('**FORMATTING:** Use <b>text</b> for bold (NOT markdown **). ');
      parts.add('Always address the user as "You" / "Your". ');
      parts.add('Every recommendation MUST include a "because" clause.\n\n');

      parts.add('**INSIGHTS SHOULD REFERENCE:** enrollment pacing, custom program pipeline velocity, ');
      parts.add('proposal-to-agreement conversion, success plan coverage, seasonal patterns, ');
      parts.add('call/outreach activity levels (using Revenue.io data), and stage movement momentum.\n\n');

      parts.add('**ACTIONS SHOULD BE SPECIFIC TO STUDY ABROAD:** e.g., "Follow up on the ');
      parts.add('University of Delaware custom program proposal because it has been in Proposal Sent ');
      parts.add('stage for 60+ days", "Increase outbound call volume because only X calls were made ');
      parts.add('this period and connected call rate suggests room for improvement", or ');
      parts.add('"Create success plans for your top 3 institutions that are pacing below 50% ');
      parts.add('because proactive engagement drives enrollment recovery."\n');

      String promptText = String.join(parts, '');

      aiplatform.ModelsAPI.createGenerations_Request request = new aiplatform.ModelsAPI.createGenerations_Request();
      request.modelName = modelName;
      aiplatform.ModelsAPI_GenerationRequest requestBody = new aiplatform.ModelsAPI_GenerationRequest();
      request.body = requestBody;
      requestBody.prompt = promptText;

      aiplatform.ModelsAPI modelsAPI = new aiplatform.ModelsAPI();
      aiplatform.ModelsAPI.createGenerations_Response response = modelsAPI.createGenerations(request);

      if (response.Code200 != null && response.Code200.generation != null) {
        return response.Code200.generation.generatedText;
      }
      return 'No response from Einstein AI.';
    } catch (aiplatform.ModelsAPI.createGenerations_ResponseException e) {
      System.debug(LoggingLevel.ERROR, 'Models API Response Exception: ' + e.getMessage());
      return 'Error: ' + e.getMessage();
    } catch (Exception e) {
      System.debug(LoggingLevel.ERROR, 'Models API Error: ' + e.getMessage());
      return 'Error: ' + e.getMessage();
    }
  }

  private static void parseAIResponse(String aiResponse, SellerPerformanceAnalysis analysis) {
    if (String.isBlank(aiResponse)) return;

    Pattern trendPattern = Pattern.compile('\\*\\*TREND:\\*\\*\\s*([^\\n]+)');
    Matcher trendMatcher = trendPattern.matcher(aiResponse);
    if (trendMatcher.find()) {
      analysis.trend = cleanHtmlText(trendMatcher.group(1).trim());
    }

    Pattern insightsPattern = Pattern.compile(
      '\\*\\*KEY INSIGHTS:\\*\\*\\s*\\n([\\s\\S]*?)\\n\\s*\\n\\s*\\*\\*RECOMMENDED ACTIONS'
    );
    Matcher insightsMatcher = insightsPattern.matcher(aiResponse);
    if (insightsMatcher.find()) {
      List<String> insights = new List<String>();
      for (String line : insightsMatcher.group(1).split('\\n')) {
        line = line.trim();
        if (line.startsWith('-')) {
          insights.add(cleanHtmlText(line.substring(1).trim()));
        }
      }
      analysis.keyInsights = insights;
    }

    Pattern actionsPattern = Pattern.compile(
      '\\*\\*RECOMMENDED ACTIONS:\\*\\*\\s*\\n([\\s\\S]*?)(?:\\n\\s*\\n|$)'
    );
    Matcher actionsMatcher = actionsPattern.matcher(aiResponse);
    if (actionsMatcher.find()) {
      List<String> actions = new List<String>();
      for (String line : actionsMatcher.group(1).split('\\n')) {
        line = line.trim();
        if (line.startsWith('-')) {
          actions.add(cleanHtmlText(line.substring(1).trim()));
        }
      }
      analysis.recommendedActions = actions;
    }
  }

  private static String cleanHtmlText(String text) {
    if (String.isBlank(text)) return text;
    text = text.replaceAll('\\*\\*([^*]+)\\*\\*', '<b>$1</b>');
    text = text.replaceAll('\\*([^*]+)\\*', '$1');
    return text;
  }

  private static String formatCurrency(Decimal amount) {
    if (amount == null || amount == 0) return '$0';
    if (amount >= 1000000) return '$' + (amount / 1000000).setScale(1) + 'M';
    if (amount >= 1000) return '$' + (amount / 1000).setScale(1) + 'K';
    return '$' + amount.setScale(0);
  }
}
