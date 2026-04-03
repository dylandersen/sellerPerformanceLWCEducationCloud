public with sharing class SellerPerformanceAnalysis {
  @AuraEnabled public Integer score;
  @AuraEnabled public String performanceStatus;
  @AuraEnabled public String trend;
  @AuraEnabled public SellerPerformanceMetrics metrics;
  @AuraEnabled public List<String> keyInsights;
  @AuraEnabled public List<String> recommendedActions;
  @AuraEnabled public String errorMessage;

  // Category sub-scores exposed so the LWC can show a breakdown
  @AuraEnabled public Integer enrollmentScore;
  @AuraEnabled public Integer pipelineScore;
  @AuraEnabled public Integer partnershipScore;
  @AuraEnabled public Integer engagementScore;

  public SellerPerformanceAnalysis() {
    this.score = 0;
    this.performanceStatus = 'Unknown';
    this.trend = 'Stable';
    this.metrics = new SellerPerformanceMetrics();
    this.keyInsights = new List<String>();
    this.recommendedActions = new List<String>();
    this.errorMessage = '';
    this.enrollmentScore = 0;
    this.pipelineScore = 0;
    this.partnershipScore = 0;
    this.engagementScore = 0;
  }
}
