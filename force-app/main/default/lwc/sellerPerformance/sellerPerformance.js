import { LightningElement, track } from "lwc";
import USER_ID from "@salesforce/user/Id";
import getSellerPerformance from "@salesforce/apex/SellerPerformanceController.getSellerPerformance";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import AGENTFORCE_ICON from "@salesforce/resourceUrl/AgentforceRGBIcon";

export default class SellerPerformance extends LightningElement {
  @track performanceData;
  @track metrics;
  @track isLoading = false;
  @track hasError = false;
  @track errorMessage = "";
  @track currentLoadingMessage = "";
  @track healthAssessmentExpanded = false;
  @track trendExpanded = false;
  agentforceIcon = AGENTFORCE_ICON;

  loadingMessages = [
    "Analyzing your study abroad portfolio with Agentforce...",
    "Gathering enrollment pacing data...",
    "Evaluating custom program pipeline...",
    "Assessing partnership development...",
    "Reviewing institutional engagement...",
    "Generating AI-powered insights..."
  ];
  loadingMessageInterval = null;
  loadingMessageIndex = 0;

  disconnectedCallback() {
    this.stopLoadingMessages();
  }

  startLoadingMessages() {
    this.loadingMessageIndex = 0;
    this.currentLoadingMessage = this.loadingMessages[this.loadingMessageIndex];
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    this.loadingMessageInterval = setInterval(() => {
      this.loadingMessageIndex =
        (this.loadingMessageIndex + 1) % this.loadingMessages.length;
      this.currentLoadingMessage =
        this.loadingMessages[this.loadingMessageIndex];
    }, 3000);
  }

  stopLoadingMessages() {
    if (this.loadingMessageInterval) {
      clearInterval(this.loadingMessageInterval);
      this.loadingMessageInterval = null;
    }
    this.currentLoadingMessage = "";
  }

  handleRefresh() {
    this.isLoading = true;
    this.hasError = false;
    this.errorMessage = "";
    this.startLoadingMessages();

    getSellerPerformance({ userId: USER_ID })
      .then((result) => {
        this.performanceData = {
          performanceStatus: result.performanceStatus,
          score: result.score,
          trend: result.trend,
          keyInsights: result.keyInsights || [],
          recommendedActions: result.recommendedActions || [],
          enrollmentScore: result.enrollmentScore || 0,
          pipelineScore: result.pipelineScore || 0,
          partnershipScore: result.partnershipScore || 0,
          engagementScore: result.engagementScore || 0
        };
        this.metrics = result.metrics;
        if (result.errorMessage) {
          this.hasError = true;
          this.errorMessage = result.errorMessage;
          this.showToast("Warning", result.errorMessage, "warning");
        }
      })
      .catch((error) => {
        this.hasError = true;
        this.errorMessage = "Unable to load performance data.";
        console.error("Error loading performance data:", error);
        this.showToast(
          "Error",
          "Failed to load performance: " +
            (error.body?.message || error.message),
          "error"
        );
      })
      .finally(() => {
        this.isLoading = false;
        this.stopLoadingMessages();
      });
  }

  showToast(title, message, variant) {
    this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
  }

  // ── Computed: visibility ──
  get hasData() {
    return this.performanceData && !this.isLoading;
  }
  get showEmptyState() {
    return !this.isLoading && !this.hasData && !this.hasError;
  }
  get hasKeyInsights() {
    return this.performanceData?.keyInsights?.length > 0;
  }
  get hasRecommendedActions() {
    return this.performanceData?.recommendedActions?.length > 0;
  }
  get hasInsightsOrActions() {
    return this.hasKeyInsights || this.hasRecommendedActions;
  }

  // ── Computed: score gauge ──
  get scoreColor() {
    if (!this.performanceData) return "#dddbda";
    const s = this.performanceData.score;
    if (s >= 80) return "#4bca81";
    if (s >= 60) return "#17a2b8";
    if (s >= 40) return "#ffb75d";
    return "#ea001e";
  }
  get progressDashArray() {
    return 2 * Math.PI * 70;
  }
  get progressDashOffset() {
    if (!this.performanceData) return this.progressDashArray;
    return this.progressDashArray * (1 - this.performanceData.score / 100);
  }

  // ── Computed: status ──
  get performanceEmoji() {
    if (!this.performanceData) return "❓";
    switch (this.performanceData.performanceStatus) {
      case "Crushing It": return "🌟";
      case "On Target": return "✅";
      case "Needs Attention": return "⚠️";
      case "Struggling": return "🔴";
      default: return "❓";
    }
  }
  get performanceStatusClass() {
    if (!this.performanceData) return "unknown";
    return (
      this.performanceData.performanceStatus?.toLowerCase().replace(" ", "-") ||
      "unknown"
    );
  }
  get statusExplanation() {
    if (!this.performanceData) return "";
    const s = this.performanceData.score;
    if (s >= 80) return `Score of ${s} exceeds your target of 80+. Excellent!`;
    if (s >= 60) return `Score of ${s} is within target (60-79). Great job!`;
    if (s >= 40) return `Score of ${s} is ${60 - s} points below target (60+).`;
    return `Score of ${s} is below target. Focus on key areas.`;
  }

  // ── Computed: trend ──
  get trendIcon() {
    const t = this.performanceData?.trend || "";
    if (t.includes("Accelerating")) return "utility:arrowup";
    if (t.includes("Declining")) return "utility:arrowdown";
    return "utility:forward";
  }
  get trendClass() {
    const t = this.performanceData?.trend || "";
    if (t.includes("Accelerating")) return "trend-accelerating";
    if (t.includes("Declining")) return "trend-slowing";
    return "trend-steady";
  }
  get trendLabel() {
    const t = this.performanceData?.trend || "";
    if (t.includes("Accelerating")) return "Accelerating";
    if (t.includes("Declining")) return "Declining";
    return "Steady";
  }
  get trendExplanation() {
    const t = this.performanceData?.trend || "";
    if (t.includes("Accelerating")) return "Enrollment & programs improving";
    if (t.includes("Declining")) return "Pipeline or enrollment weakening";
    return "Performance holding steady";
  }

  // ── Computed: enrollment pacing ──
  get enrollmentPacingPct() {
    return this._safeNum(this.metrics?.enrollmentPacingPct);
  }
  get enrollmentPacingFormatted() {
    return this.enrollmentPacingPct.toFixed(1) + "%";
  }
  get enrollmentPacingStatus() {
    const p = this.enrollmentPacingPct;
    if (p >= 100) return "On Track";
    if (p >= 75) return "Pacing Well";
    if (p >= 50) return "Behind";
    if (p > 0) return "At Risk";
    return "No Data";
  }
  get enrollmentPacingBadgeClass() {
    const s = this.enrollmentPacingStatus;
    const base = "velocity-badge";
    if (s === "On Track" || s === "Pacing Well") return `${base} velocity-fast`;
    if (s === "Behind") return `${base} velocity-average`;
    if (s === "At Risk") return `${base} velocity-slow`;
    return `${base} velocity-none`;
  }
  get forecastedStudents() {
    return this._safeNum(this.metrics?.forecastedStudents).toFixed(0);
  }
  get activeEnrollment() {
    return this._safeNum(this.metrics?.activeEnrollment).toFixed(0);
  }

  // ── Computed: program pipeline ──
  get openPrograms() {
    return (
      this._safeInt(this.metrics?.openCustomPrograms) +
      this._safeInt(this.metrics?.openCohortPrograms)
    );
  }
  get programsWon() {
    return this._safeInt(this.metrics?.programsWon);
  }
  get stagnantPrograms() {
    return this._safeInt(this.metrics?.stagnantPrograms);
  }
  get customProgramWinRate() {
    return this._safeNum(this.metrics?.customProgramWinRate);
  }
  get customProgramWinRateFormatted() {
    return this.customProgramWinRate.toFixed(1) + "%";
  }

  // Pipeline stage bar
  get pipelineActiveCount() {
    return (
      this._safeInt(this.metrics?.programsNew) +
      this._safeInt(this.metrics?.programsInDevelopment) +
      this._safeInt(this.metrics?.programsProposalSent)
    );
  }
  get pipelineStagnantCount() {
    return this._safeInt(this.metrics?.stagnantPrograms);
  }
  get pipelineTotalOpen() {
    return this.openPrograms;
  }
  get pipelineActiveBarStyle() {
    const total = this.pipelineTotalOpen;
    if (total === 0) return "width: 100%;";
    const active = Math.max(0, total - this.pipelineStagnantCount);
    return `width: ${(active / total) * 100}%;`;
  }
  get pipelineStagnantBarStyle() {
    const total = this.pipelineTotalOpen;
    if (total === 0) return "width: 0%;";
    return `width: ${(this.pipelineStagnantCount / total) * 100}%;`;
  }
  get pipelineExplanation() {
    const stagnant = this.pipelineStagnantCount;
    if (stagnant === 0) return "All programs progressing through pipeline";
    return `${stagnant} program${stagnant > 1 ? "s" : ""} stagnant 30+ days`;
  }
  get stagnantTextStyle() {
    const s = this.pipelineStagnantCount;
    if (s === 0) return "color: #4bca81;";
    if (s <= 3) return "color: #ffb75d;";
    return "color: #ea001e;";
  }

  // ── Computed: partnership ──
  get proposalsSent() {
    return this._safeInt(this.metrics?.proposalsSent);
  }
  get agreementsSigned() {
    return this._safeInt(this.metrics?.agreementsSigned);
  }
  get projectedRevenue() {
    return this._safeNum(this.metrics?.projectedRevenue);
  }
  get projectedRevenueFormatted() {
    return this._formatCurrency(this.projectedRevenue);
  }
  get forecastedRevenue() {
    return this._safeNum(this.metrics?.forecastedRevenue);
  }
  get forecastedRevenueFormatted() {
    return this._formatCurrency(this.forecastedRevenue);
  }

  // ── Computed: engagement ──
  get successPlansActive() {
    return this._safeInt(this.metrics?.successPlansActive);
  }
  get homeInstitutionsManaged() {
    return this._safeInt(this.metrics?.homeInstitutionsManaged);
  }

  // ── Computed: sales activity ──
  get callsMade() {
    return this._safeInt(this.metrics?.callsMade);
  }
  get callsInbound() {
    return this._safeInt(this.metrics?.callsInbound);
  }
  get callsConnected() {
    return this._safeInt(this.metrics?.callsConnected);
  }
  get totalTalkTimeMins() {
    return this._safeNum(this.metrics?.totalTalkTimeMins);
  }
  get totalTalkTimeFormatted() {
    const mins = this.totalTalkTimeMins;
    if (mins >= 60) return (mins / 60).toFixed(1) + "h";
    return mins.toFixed(0) + "m";
  }
  get emailsSent() {
    return this._safeInt(this.metrics?.emailsSent);
  }
  get meetingsHeld() {
    return this._safeInt(this.metrics?.meetingsHeld);
  }
  get tasksCompleted() {
    return this._safeInt(this.metrics?.tasksCompleted);
  }

  // ── Computed: stage movement ──
  get stageNewCount() {
    return this._safeInt(this.metrics?.stageNewCount);
  }
  get stageInDevCount() {
    return this._safeInt(this.metrics?.stageInDevCount);
  }
  get stageProposalCount() {
    return this._safeInt(this.metrics?.stageProposalCount);
  }
  get stageQualifiedCount() {
    return this._safeInt(this.metrics?.stageQualifiedCount);
  }
  get stageAgreementCount() {
    return this._safeInt(this.metrics?.stageAgreementCount);
  }
  get stageRosterCount() {
    return this._safeInt(this.metrics?.stageRosterCount);
  }
  get dealsAdvancingCount() {
    return this._safeInt(this.metrics?.dealsAdvancingCount);
  }
  get dealsAdvancingPlural() {
    return this.dealsAdvancingCount === 1 ? "" : "s";
  }

  // Stage funnel colour scales (darker = more opps)
  _funnelStyle(count, maxCount, hue) {
    const pct = maxCount > 0 ? count / maxCount : 0;
    const lightness = Math.round(95 - pct * 35); // 95% (empty) → 60% (full)
    const saturation = Math.round(30 + pct * 50);
    return `background: hsl(${hue}, ${saturation}%, ${lightness}%); color: hsl(${hue}, 60%, 28%);`;
  }
  get _funnelMax() {
    return Math.max(
      1,
      this.stageNewCount,
      this.stageInDevCount,
      this.stageProposalCount,
      this.stageQualifiedCount,
      this.stageAgreementCount,
      this.stageRosterCount
    );
  }
  get funnelNewStyle() {
    return this._funnelStyle(this.stageNewCount, this._funnelMax, 210);
  }
  get funnelInDevStyle() {
    return this._funnelStyle(this.stageInDevCount, this._funnelMax, 200);
  }
  get funnelProposalStyle() {
    return this._funnelStyle(this.stageProposalCount, this._funnelMax, 190);
  }
  get funnelQualifiedStyle() {
    return this._funnelStyle(this.stageQualifiedCount, this._funnelMax, 170);
  }
  get funnelAgreementStyle() {
    return this._funnelStyle(this.stageAgreementCount, this._funnelMax, 150);
  }
  get funnelRosterStyle() {
    return this._funnelStyle(this.stageRosterCount, this._funnelMax, 140);
  }

  // Stage movement expand/collapse
  @track stageMovementExpanded = false;
  get showStageMovementDetails() {
    return this.stageMovementExpanded;
  }
  toggleStageMovement() {
    this.stageMovementExpanded = !this.stageMovementExpanded;
  }

  // ── Tooltip getters ──
  get forecastedStudentsTooltip() {
    return this.metrics?.forecastedStudentsTooltip || "";
  }
  get activeEnrollmentTooltip() {
    return this.metrics?.activeEnrollmentTooltip || "";
  }
  get openProgramsTooltip() {
    return this.metrics?.openProgramsTooltip || "";
  }
  get programsWonTooltip() {
    return this.metrics?.programsWonTooltip || "";
  }
  get proposalsSentTooltip() {
    return this.metrics?.proposalsSentTooltip || "";
  }
  get projectedRevenueTooltip() {
    return this.metrics?.projectedRevenueTooltip || "";
  }
  get successPlansTooltip() {
    return this.metrics?.successPlansTooltip || "";
  }
  get institutionsTooltip() {
    return this.metrics?.institutionsTooltip || "";
  }
  get enrollmentPacingTooltip() {
    return this.metrics?.enrollmentPacingTooltip || "";
  }
  get pipelineStageTooltip() {
    return this.metrics?.pipelineStageTooltip || "";
  }
  get healthAssessmentTooltip() {
    return this.metrics?.healthAssessmentTooltip || "";
  }
  get trendTooltip() {
    return this.metrics?.trendTooltip || "";
  }
  get callsTooltip() {
    return this.metrics?.callsTooltip || "";
  }
  get activityTooltip() {
    return this.metrics?.activityTooltip || "";
  }
  get stageMovementTooltip() {
    return this.metrics?.stageMovementTooltip || "";
  }
  get callsMadeTooltip() {
    return this.metrics?.callsMadeTooltip || "";
  }
  get callsConnectedTooltip() {
    return this.metrics?.callsConnectedTooltip || "";
  }
  get talkTimeTooltip() {
    return this.metrics?.talkTimeTooltip || "";
  }
  get emailsSentTooltip() {
    return this.metrics?.emailsSentTooltip || "";
  }
  get meetingsTooltip() {
    return this.metrics?.meetingsTooltip || "";
  }
  get tasksDoneTooltip() {
    return this.metrics?.tasksDoneTooltip || "";
  }

  // ── Expand / collapse ──
  get healthAssessmentDetailsClass() {
    let c = "expandable-details health-assessment-details";
    if (this.healthAssessmentCollapsing) c += " collapsing";
    return c;
  }
  get trendDetailsClass() {
    let c = "expandable-details trend-details";
    if (this.trendCollapsing) c += " collapsing";
    return c;
  }
  get showHealthAssessmentDetails() {
    return this.healthAssessmentExpanded || this.healthAssessmentCollapsing;
  }
  get showTrendDetails() {
    return this.trendExpanded || this.trendCollapsing;
  }
  toggleHealthAssessment() {
    if (this.healthAssessmentExpanded) {
      this.healthAssessmentExpanded = false;
      this.healthAssessmentCollapsing = false;
    } else {
      this.healthAssessmentCollapsing = false;
      this.healthAssessmentExpanded = true;
    }
  }
  toggleTrend() {
    if (this.trendExpanded) {
      this.trendExpanded = false;
      this.trendCollapsing = false;
    } else {
      this.trendCollapsing = false;
      this.trendExpanded = true;
    }
  }

  // ── Helpers ──
  _safeNum(v) {
    if (v == null || v === "") return 0;
    const n = Number(v);
    return isNaN(n) ? 0 : n;
  }
  _safeInt(v) {
    return Math.round(this._safeNum(v));
  }
  _formatCurrency(v) {
    const n = this._safeNum(v);
    if (n >= 1000000) return "$" + (n / 1000000).toFixed(1) + "M";
    if (n >= 1000) return "$" + (n / 1000).toFixed(1) + "K";
    return "$" + n.toFixed(0);
  }
}
