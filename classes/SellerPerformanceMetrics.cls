public with sharing class SellerPerformanceMetrics {
  // Activity metrics
  @AuraEnabled
  public Integer callCount;

  @AuraEnabled
  public Integer emailCount;

  @AuraEnabled
  public Integer meetingCount;

  @AuraEnabled
  public Integer taskCount;

  @AuraEnabled
  public Integer completedTasksCount;

  @AuraEnabled
  public Integer scheduledFollowUpsCount;

  // Pipeline metrics
  @AuraEnabled
  public Decimal totalPipelineValue;

  @AuraEnabled
  public Integer opportunitiesCount;

  @AuraEnabled
  public Integer opportunitiesWonCount;

  @AuraEnabled
  public Integer opportunitiesLostCount;

  @AuraEnabled
  public Integer newOpportunitiesCount;

  @AuraEnabled
  public Integer stagnantDealsCount;

  // Deal execution
  @AuraEnabled
  public Decimal winRate;

  @AuraEnabled
  public Decimal totalRevenue;

  @AuraEnabled
  public Decimal avgDealSize;

  @AuraEnabled
  public Decimal closeDateAccuracy;

  @AuraEnabled
  public Integer dealsClosedWon;

  @AuraEnabled
  public Integer dealsClosedLost;

  // Relationship metrics
  @AuraEnabled
  public Integer contactsEngagedCount;

  @AuraEnabled
  public Integer newRelationshipsCount;

  @AuraEnabled
  public Integer highPriorityAccountInteractions;

  // Pipeline health
  @AuraEnabled
  public Integer atRiskDealsCount;

  @AuraEnabled
  public Integer pastDueCloseDatesCount;

  @AuraEnabled
  public Integer dealsAdvancingCount;

  @AuraEnabled
  public Decimal dealVelocity;

  // Tooltip data for detailed breakdowns
  @AuraEnabled
  public String callsTooltip;

  @AuraEnabled
  public String emailsTooltip;

  @AuraEnabled
  public String meetingsTooltip;

  @AuraEnabled
  public String tasksTooltip;

  @AuraEnabled
  public String pipelineValueTooltip;

  @AuraEnabled
  public String winRateTooltip;

  @AuraEnabled
  public String revenueTooltip;

  @AuraEnabled
  public String opportunitiesTooltip;

  @AuraEnabled
  public String contactsEngagedTooltip;

  @AuraEnabled
  public String atRiskDealsTooltip;

  @AuraEnabled
  public String pipelineHealthTooltip;

  @AuraEnabled
  public String dealVelocityTooltip;

  @AuraEnabled
  public String healthAssessmentTooltip;

  @AuraEnabled
  public String trendTooltip;

  public SellerPerformanceMetrics() {
    this.callCount = 0;
    this.emailCount = 0;
    this.meetingCount = 0;
    this.taskCount = 0;
    this.completedTasksCount = 0;
    this.scheduledFollowUpsCount = 0;
    this.totalPipelineValue = 0;
    this.opportunitiesCount = 0;
    this.opportunitiesWonCount = 0;
    this.opportunitiesLostCount = 0;
    this.newOpportunitiesCount = 0;
    this.stagnantDealsCount = 0;
    this.winRate = 0;
    this.totalRevenue = 0;
    this.avgDealSize = 0;
    this.closeDateAccuracy = 0;
    this.dealsClosedWon = 0;
    this.dealsClosedLost = 0;
    this.contactsEngagedCount = 0;
    this.newRelationshipsCount = 0;
    this.highPriorityAccountInteractions = 0;
    this.atRiskDealsCount = 0;
    this.pastDueCloseDatesCount = 0;
    this.dealsAdvancingCount = 0;
    this.dealVelocity = 0;
    this.callsTooltip = '';
    this.emailsTooltip = '';
    this.meetingsTooltip = '';
    this.tasksTooltip = '';
    this.pipelineValueTooltip = '';
    this.winRateTooltip = '';
    this.revenueTooltip = '';
    this.opportunitiesTooltip = '';
    this.contactsEngagedTooltip = '';
    this.atRiskDealsTooltip = '';
    this.pipelineHealthTooltip = '';
    this.dealVelocityTooltip = '';
    this.healthAssessmentTooltip = '';
    this.trendTooltip = '';
  }
}
