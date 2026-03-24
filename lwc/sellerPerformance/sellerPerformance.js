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
    "Analyzing seller performance with Agentforce...",
    "Gathering activity metrics...",
    "Calculating pipeline health...",
    "Analyzing deal execution...",
    "Assessing relationship building...",
    "Generating performance insights..."
  ];
  loadingMessageInterval = null;
  loadingMessageIndex = 0;

  connectedCallback() {
    // Optionally load on initial page load
    // this.handleRefresh();
  }

  disconnectedCallback() {
    // Clean up interval when component is destroyed
    this.stopLoadingMessages();
  }

  startLoadingMessages() {
    // Reset to first message
    this.loadingMessageIndex = 0;
    // Set initial message
    this.currentLoadingMessage = this.loadingMessages[this.loadingMessageIndex];

    // Rotate messages every 3 seconds
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

    // Get current user ID
    const userId = USER_ID;

    getSellerPerformance({ userId: userId })
      .then((result) => {
        this.performanceData = {
          performanceStatus: result.performanceStatus,
          score: result.score,
          trend: result.trend,
          keyInsights: result.keyInsights || [],
          recommendedActions: result.recommendedActions || []
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
        this.errorMessage = "Unable to load seller performance data.";
        console.error("Error loading performance data:", error);
        this.showToast(
          "Error",
          "Failed to load seller performance: " +
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
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(event);
  }

  get hasData() {
    return this.performanceData && !this.isLoading;
  }

  get performanceEmoji() {
    if (!this.performanceData) return "❓";
    switch (this.performanceData.performanceStatus) {
      case "Crushing It":
        return "🌟";
      case "On Target":
        return "✅";
      case "Needs Attention":
        return "⚠️";
      case "Struggling":
        return "🔴";
      default:
        return "❓";
    }
  }

  get performanceStatusClass() {
    if (!this.performanceData) return "unknown";
    const status = this.performanceData.performanceStatus
      ?.toLowerCase()
      .replace(" ", "-");
    return status || "unknown";
  }

  get trendIcon() {
    if (!this.performanceData) return "utility:forward";
    const trend = this.performanceData.trend;
    if (trend && trend.includes("Accelerating")) return "utility:arrowup";
    if (trend && trend.includes("Declining")) return "utility:arrowdown";
    if (trend && trend.includes("Steady")) return "utility:forward";
    return "utility:forward";
  }

  get trendClass() {
    if (!this.performanceData) return "";
    const trend = this.performanceData.trend;
    if (trend && trend.includes("Accelerating")) return "trend-accelerating";
    if (trend && trend.includes("Declining")) return "trend-slowing";
    if (trend && trend.includes("Steady")) return "trend-steady";
    return "";
  }

  get showEmptyState() {
    return !this.isLoading && !this.hasData && !this.hasError;
  }

  // Circular progress gauge calculations
  get scoreColor() {
    if (!this.performanceData) return "#dddbda";
    const score = this.performanceData.score;
    if (score >= 80) return "#4bca81"; // Green - Crushing It
    if (score >= 60) return "#17a2b8"; // Teal - On Target
    if (score >= 40) return "#ffb75d"; // Yellow - Needs Attention
    return "#ea001e"; // Red - Struggling
  }

  get progressDashArray() {
    const circumference = 2 * Math.PI * 70; // radius = 70
    return circumference;
  }

  get progressDashOffset() {
    if (!this.performanceData) return this.progressDashArray;
    const circumference = this.progressDashArray;
    const score = this.performanceData.score;
    const progress = score / 100;
    return circumference * (1 - progress);
  }

  // Metric getters
  get callCount() {
    return this.metrics?.callCount || 0;
  }

  get emailCount() {
    return this.metrics?.emailCount || 0;
  }

  get meetingCount() {
    return this.metrics?.meetingCount || 0;
  }

  get taskCount() {
    return this.metrics?.taskCount || 0;
  }

  get completedTasksCount() {
    return this.metrics?.completedTasksCount || 0;
  }

  get scheduledFollowUpsCount() {
    return this.metrics?.scheduledFollowUpsCount || 0;
  }

  get totalPipelineValue() {
    return this.metrics?.totalPipelineValue || 0;
  }

  get totalPipelineValueFormatted() {
    const rawValue = this.totalPipelineValue;
    const value = rawValue == null || rawValue === "" ? 0 : Number(rawValue);
    const numValue = isNaN(value) ? 0 : value;
    if (numValue >= 1000000) {
      return "$" + (numValue / 1000000).toFixed(1) + "M";
    } else if (numValue >= 1000) {
      return "$" + (numValue / 1000).toFixed(1) + "K";
    }
    return "$" + numValue.toFixed(0);
  }

  get opportunitiesCount() {
    return this.metrics?.opportunitiesCount || 0;
  }

  get newOpportunitiesCount() {
    return this.metrics?.newOpportunitiesCount || 0;
  }

  get stagnantDealsCount() {
    return this.metrics?.stagnantDealsCount || 0;
  }

  get winRate() {
    const value = this.metrics?.winRate;
    // Ensure we return a number, handling null, undefined, empty string, etc.
    if (value == null || value === "") {
      return 0;
    }
    const numValue = Number(value);
    return isNaN(numValue) ? 0 : numValue;
  }

  get winRateFormatted() {
    const rate = this.winRate;
    // Double-check that rate is a number before calling toFixed
    if (typeof rate !== "number" || isNaN(rate)) {
      return "0.0%";
    }
    return rate.toFixed(1) + "%";
  }

  get totalRevenue() {
    return this.metrics?.totalRevenue || 0;
  }

  get totalRevenueFormatted() {
    const rawValue = this.totalRevenue;
    const value = rawValue == null || rawValue === "" ? 0 : Number(rawValue);
    const numValue = isNaN(value) ? 0 : value;
    if (numValue >= 1000000) {
      return "$" + (numValue / 1000000).toFixed(1) + "M";
    } else if (numValue >= 1000) {
      return "$" + (numValue / 1000).toFixed(1) + "K";
    }
    return "$" + numValue.toFixed(0);
  }

  get avgDealSize() {
    return this.metrics?.avgDealSize || 0;
  }

  get avgDealSizeFormatted() {
    const rawValue = this.avgDealSize;
    const value = rawValue == null || rawValue === "" ? 0 : Number(rawValue);
    const numValue = isNaN(value) ? 0 : value;
    if (numValue >= 1000000) {
      return "$" + (numValue / 1000000).toFixed(1) + "M";
    } else if (numValue >= 1000) {
      return "$" + (numValue / 1000).toFixed(1) + "K";
    }
    return "$" + numValue.toFixed(0);
  }

  get dealsClosedWon() {
    return this.metrics?.dealsClosedWon || 0;
  }

  get dealsClosedLost() {
    return this.metrics?.dealsClosedLost || 0;
  }

  get contactsEngagedCount() {
    return this.metrics?.contactsEngagedCount || 0;
  }

  get newRelationshipsCount() {
    return this.metrics?.newRelationshipsCount || 0;
  }

  get highPriorityAccountInteractions() {
    return this.metrics?.highPriorityAccountInteractions || 0;
  }

  get atRiskDealsCount() {
    return this.metrics?.atRiskDealsCount || 0;
  }

  get pastDueCloseDatesCount() {
    return this.metrics?.pastDueCloseDatesCount || 0;
  }

  get dealsAdvancingCount() {
    return this.metrics?.dealsAdvancingCount || 0;
  }

  get dealVelocity() {
    const velocity = this.metrics?.dealVelocity;
    if (velocity == null || velocity === "") {
      return 0;
    }
    const numValue = Number(velocity);
    return isNaN(numValue) ? 0 : numValue;
  }

  get dealVelocityFormatted() {
    const velocity = this.dealVelocity;
    if (velocity == null || velocity === 0) {
      return "No Data";
    }
    // Double-check that velocity is a number before calling toFixed
    if (typeof velocity !== "number" || isNaN(velocity)) {
      return "No Data";
    }
    return velocity.toFixed(1) + " days";
  }

  // Tooltip getters
  get callsTooltip() {
    return this.metrics?.callsTooltip || "";
  }

  get emailsTooltip() {
    return this.metrics?.emailsTooltip || "";
  }

  get meetingsTooltip() {
    return this.metrics?.meetingsTooltip || "";
  }

  get tasksTooltip() {
    return this.metrics?.tasksTooltip || "";
  }

  get pipelineValueTooltip() {
    return this.metrics?.pipelineValueTooltip || "";
  }

  get winRateTooltip() {
    return this.metrics?.winRateTooltip || "";
  }

  get revenueTooltip() {
    return this.metrics?.revenueTooltip || "";
  }

  get opportunitiesTooltip() {
    return this.metrics?.opportunitiesTooltip || "";
  }

  get contactsEngagedTooltip() {
    return this.metrics?.contactsEngagedTooltip || "";
  }

  get atRiskDealsTooltip() {
    return this.metrics?.atRiskDealsTooltip || "";
  }

  get pipelineHealthTooltip() {
    return this.metrics?.pipelineHealthTooltip || "";
  }

  get dealVelocityTooltip() {
    return this.metrics?.dealVelocityTooltip || "";
  }

  get healthAssessmentTooltip() {
    return this.metrics?.healthAssessmentTooltip || "";
  }

  get trendTooltip() {
    return this.metrics?.trendTooltip || "";
  }

  get hasAtRiskDeals() {
    return (this.metrics?.atRiskDealsCount || 0) > 0;
  }

  // Status explanation based on score thresholds
  get statusExplanation() {
    if (!this.performanceData) return "";
    const score = this.performanceData.score;
    if (score >= 80) {
      return `Your score of ${score} exceeds your target of 80+, excellent work!`;
    } else if (score >= 60) {
      return `Your score of ${score} is within your target of 60-79, great job!`;
    } else if (score >= 40) {
      const pointsBelow = 60 - score;
      return `Your score of ${score} is ${pointsBelow} point${pointsBelow > 1 ? "s" : ""} below your target of 60-79.`;
    }
    return `Your score of ${score} is below your target. Focus on improving key metrics.`;
  }

  // Trend label (just the word)
  get trendLabel() {
    if (!this.performanceData?.trend) return "Steady";
    const trend = this.performanceData.trend;
    if (trend.includes("Accelerating")) return "Accelerating";
    if (trend.includes("Declining")) return "Declining";
    return "Steady";
  }

  // Trend explanation
  get trendExplanation() {
    if (!this.performanceData?.trend) return "Performance holding steady";
    const trend = this.performanceData.trend;
    if (trend.includes("Accelerating")) {
      return "Activity & deals improving";
    }
    if (trend.includes("Declining")) {
      return "Activity or pipeline weakening";
    }
    return "Performance holding steady";
  }

  // Healthy deals count (open deals that aren't at-risk)
  get healthyDealsCount() {
    if (!this.metrics) return 0;
    const totalOpen =
      (this.metrics.opportunitiesCount || 0) -
      (this.metrics.opportunitiesWonCount || 0) -
      (this.metrics.opportunitiesLostCount || 0);
    const atRisk = this.metrics.atRiskDealsCount || 0;
    return Math.max(0, totalOpen - atRisk);
  }

  // Total open deals
  get totalOpenDeals() {
    if (!this.metrics) return 0;
    const totalOpen =
      (this.metrics.opportunitiesCount || 0) -
      (this.metrics.opportunitiesWonCount || 0) -
      (this.metrics.opportunitiesLostCount || 0);
    return Math.max(0, totalOpen);
  }

  // Pipeline health bar styles
  get pipelineHealthyBarStyle() {
    const total = this.totalOpenDeals;
    if (total === 0) return "width: 100%;";
    const healthyPercent = (this.healthyDealsCount / total) * 100;
    return `width: ${healthyPercent}%;`;
  }

  get pipelineAtRiskBarStyle() {
    const total = this.totalOpenDeals;
    if (total === 0) return "width: 0%;";
    const atRiskPercent = ((this.metrics?.atRiskDealsCount || 0) / total) * 100;
    return `width: ${atRiskPercent}%;`;
  }

  // At-risk text color style
  get atRiskTextStyle() {
    const atRisk = this.metrics?.atRiskDealsCount || 0;
    if (atRisk === 0) return "color: #4bca81;";
    if (atRisk <= 5) return "color: #ffb75d;";
    return "color: #ea001e;";
  }

  // Pipeline health explanation
  get pipelineHealthExplanation() {
    const atRisk = this.metrics?.atRiskDealsCount || 0;
    const pastDue = this.metrics?.pastDueCloseDatesCount || 0;
    if (atRisk === 0) {
      return "All deals on track with valid close dates";
    }
    if (pastDue > 0) {
      return `${pastDue} past due close dates, ${atRisk - pastDue} closing within 7 days`;
    }
    return `${atRisk} deals closing within 7 days`;
  }

  // Deal velocity status
  get velocityStatus() {
    const velocity = this.metrics?.dealVelocity || 0;
    if (velocity === 0) return "No Data";
    if (velocity <= 7) return "Fast";
    if (velocity <= 14) return "Good";
    if (velocity <= 21) return "Average";
    return "Slow";
  }

  // Velocity badge class
  get velocityBadgeClass() {
    const status = this.velocityStatus;
    const baseClass = "velocity-badge";
    if (status === "Fast" || status === "Good")
      return `${baseClass} velocity-fast`;
    if (status === "Average") return `${baseClass} velocity-average`;
    if (status === "Slow") return `${baseClass} velocity-slow`;
    return `${baseClass} velocity-none`;
  }

  get pipelineHealthColor() {
    if (!this.metrics) return "#4bca81";
    const atRisk = this.metrics.atRiskDealsCount || 0;
    if (atRisk === 0) {
      return "#4bca81"; // Green
    }
    if (atRisk <= 5) {
      return "#ffb75d"; // Yellow
    }
    return "#ea001e"; // Red
  }

  get pipelineHealthStyle() {
    return `color: ${this.pipelineHealthColor};`;
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

  get healthAssessmentDetailsClass() {
    let classes = "expandable-details health-assessment-details";
    if (this.healthAssessmentCollapsing) {
      classes += " collapsing";
    }
    return classes;
  }

  get trendDetailsClass() {
    let classes = "expandable-details trend-details";
    if (this.trendCollapsing) {
      classes += " collapsing";
    }
    return classes;
  }

  get showHealthAssessmentDetails() {
    return this.healthAssessmentExpanded || this.healthAssessmentCollapsing;
  }

  get showTrendDetails() {
    return this.trendExpanded || this.trendCollapsing;
  }

  toggleHealthAssessment() {
    if (this.healthAssessmentExpanded) {
      // Collapse immediately
      this.healthAssessmentExpanded = false;
      this.healthAssessmentCollapsing = false;
    } else {
      // Expanding
      this.healthAssessmentCollapsing = false;
      this.healthAssessmentExpanded = true;
    }
  }

  toggleTrend() {
    if (this.trendExpanded) {
      // Collapse immediately
      this.trendExpanded = false;
      this.trendCollapsing = false;
    } else {
      // Expanding
      this.trendCollapsing = false;
      this.trendExpanded = true;
    }
  }
}
