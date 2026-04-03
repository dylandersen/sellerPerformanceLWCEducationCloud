public with sharing class SellerPerformanceMetrics {

  // ── Enrollment Pacing ──
  @AuraEnabled public Decimal forecastedStudents;
  @AuraEnabled public Decimal activeEnrollment;
  @AuraEnabled public Decimal enrollmentPacingPct;
  @AuraEnabled public Integer appsStarted;
  @AuraEnabled public Decimal forecastedRevenue;
  @AuraEnabled public Decimal projectedRevenue;

  // ── Program Pipeline ──
  @AuraEnabled public Integer openCustomPrograms;
  @AuraEnabled public Integer openCohortPrograms;
  @AuraEnabled public Integer programsWon;
  @AuraEnabled public Integer programsLost;
  @AuraEnabled public Integer programsDNP;
  @AuraEnabled public Decimal customProgramWinRate;
  @AuraEnabled public Integer stagnantPrograms;
  @AuraEnabled public Integer programsInDevelopment;
  @AuraEnabled public Integer programsProposalSent;
  @AuraEnabled public Integer programsNew;

  // ── Stage Movement (Custom + Cohort opps, 30d) ──
  @AuraEnabled public Integer dealsAdvancingCount;   // stage changes in period
  @AuraEnabled public Integer stageNewCount;
  @AuraEnabled public Integer stageInDevCount;
  @AuraEnabled public Integer stageProposalCount;
  @AuraEnabled public Integer stageQualifiedCount;
  @AuraEnabled public Integer stageAgreementCount;
  @AuraEnabled public Integer stageRosterCount;
  @AuraEnabled public Integer stageOnSiteCount;

  // ── Partnership Development ──
  @AuraEnabled public Integer activeAccountStrategies;
  @AuraEnabled public Integer proposalsSent;
  @AuraEnabled public Integer agreementsSigned;
  @AuraEnabled public Decimal revenuePerStudent;
  @AuraEnabled public Decimal avgMargin;
  @AuraEnabled public Integer newAgreementsThisTerm;

  // ── Institutional Engagement ──
  @AuraEnabled public Integer successPlansActive;
  @AuraEnabled public Integer rfpsSubmitted;
  @AuraEnabled public Integer opportunityGroups;
  @AuraEnabled public Integer homeInstitutionsManaged;
  @AuraEnabled public Integer irMeetings;

  // ── Sales Activity (calls / emails / meetings / tasks) ──
  @AuraEnabled public Integer callsMade;         // Revenue.io outbound calls (Tasks)
  @AuraEnabled public Integer callsInbound;      // Revenue.io inbound calls (Tasks)
  @AuraEnabled public Integer callsConnected;    // calls with duration > 0
  @AuraEnabled public Decimal totalTalkTimeMins; // sum of CallDurationInSeconds / 60
  @AuraEnabled public Integer emailsSent;        // email Tasks
  @AuraEnabled public Integer meetingsHeld;      // Events
  @AuraEnabled public Integer tasksCompleted;    // completed Tasks

  // ── Tooltip data ──
  @AuraEnabled public String forecastedStudentsTooltip;
  @AuraEnabled public String activeEnrollmentTooltip;
  @AuraEnabled public String openProgramsTooltip;
  @AuraEnabled public String programsWonTooltip;
  @AuraEnabled public String proposalsSentTooltip;
  @AuraEnabled public String projectedRevenueTooltip;
  @AuraEnabled public String successPlansTooltip;
  @AuraEnabled public String institutionsTooltip;
  @AuraEnabled public String enrollmentPacingTooltip;
  @AuraEnabled public String pipelineStageTooltip;
  @AuraEnabled public String stageMovementTooltip;
  @AuraEnabled public String activityTooltip;
  @AuraEnabled public String callsTooltip;
  @AuraEnabled public String healthAssessmentTooltip;
  @AuraEnabled public String trendTooltip;

  // ── Per-card activity tooltips ──
  @AuraEnabled public String callsMadeTooltip;
  @AuraEnabled public String callsConnectedTooltip;
  @AuraEnabled public String talkTimeTooltip;
  @AuraEnabled public String emailsSentTooltip;
  @AuraEnabled public String meetingsTooltip;
  @AuraEnabled public String tasksDoneTooltip;

  public SellerPerformanceMetrics() {
    this.forecastedStudents = 0;
    this.activeEnrollment = 0;
    this.enrollmentPacingPct = 0;
    this.appsStarted = 0;
    this.forecastedRevenue = 0;
    this.projectedRevenue = 0;

    this.openCustomPrograms = 0;
    this.openCohortPrograms = 0;
    this.programsWon = 0;
    this.programsLost = 0;
    this.programsDNP = 0;
    this.customProgramWinRate = 0;
    this.stagnantPrograms = 0;
    this.programsInDevelopment = 0;
    this.programsProposalSent = 0;
    this.programsNew = 0;

    this.dealsAdvancingCount = 0;
    this.stageNewCount = 0;
    this.stageInDevCount = 0;
    this.stageProposalCount = 0;
    this.stageQualifiedCount = 0;
    this.stageAgreementCount = 0;
    this.stageRosterCount = 0;
    this.stageOnSiteCount = 0;

    this.activeAccountStrategies = 0;
    this.proposalsSent = 0;
    this.agreementsSigned = 0;
    this.revenuePerStudent = 0;
    this.avgMargin = 0;
    this.newAgreementsThisTerm = 0;

    this.successPlansActive = 0;
    this.rfpsSubmitted = 0;
    this.opportunityGroups = 0;
    this.homeInstitutionsManaged = 0;
    this.irMeetings = 0;

    this.callsMade = 0;
    this.callsInbound = 0;
    this.callsConnected = 0;
    this.totalTalkTimeMins = 0;
    this.emailsSent = 0;
    this.meetingsHeld = 0;
    this.tasksCompleted = 0;

    this.forecastedStudentsTooltip = '';
    this.activeEnrollmentTooltip = '';
    this.openProgramsTooltip = '';
    this.programsWonTooltip = '';
    this.proposalsSentTooltip = '';
    this.projectedRevenueTooltip = '';
    this.successPlansTooltip = '';
    this.institutionsTooltip = '';
    this.enrollmentPacingTooltip = '';
    this.pipelineStageTooltip = '';
    this.stageMovementTooltip = '';
    this.activityTooltip = '';
    this.callsTooltip = '';
    this.healthAssessmentTooltip = '';
    this.trendTooltip = '';
    this.callsMadeTooltip = '';
    this.callsConnectedTooltip = '';
    this.talkTimeTooltip = '';
    this.emailsSentTooltip = '';
    this.meetingsTooltip = '';
    this.tasksDoneTooltip = '';
  }
}
