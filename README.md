# Seller Performance Dashboard

A Salesforce Lightning Web Component that computes a weighted seller performance score with activity analysis, pipeline health tracking, deal execution metrics, and AI-powered insights and recommendations.

![Salesforce API 62.0](https://img.shields.io/badge/Salesforce%20API-62.0-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Screenshot

> ![Seller Performance Dashboard](sellerPerformance.png)

## Overview

Seller Performance Dashboard provides a comprehensive performance assessment for the current logged-in user. It analyzes Tasks, Events, EmailMessages, Opportunities, OpportunityFieldHistory, and Contacts to compute a composite performance score (0-100) across four weighted categories. The app includes a 30-day trend analysis, pipeline health visualization, deal velocity tracking, and AI-powered insights and recommended actions using Salesforce's Einstein Generative AI.

## Features

- **Composite Performance Score**: Weighted 0-100 score with status grade (Crushing It/On Target/Needs Attention/Struggling) and circular progress gauge
- **Four-Category Breakdown**: Activity Volume (30%), Pipeline Health (25%), Deal Execution (25%), Relationship Building (20%)
- **Health Assessment**: Expandable detail panel explaining why you received your score and how to improve
- **30-Day Trend Analysis**: AI-determined trend direction (Accelerating/Steady/Declining) with expandable detail panel
- **Pipeline Health**: Visual bar showing healthy vs. at-risk deals with specific deal callouts
- **Deal Velocity**: Average days between stage transitions with Fast/Good/Average/Slow classification
- **Activity Metrics**: Calls, emails, meetings, and tasks over the last 30 days with hover tooltips
- **Deal Execution**: Win rate, total revenue, pipeline value, and contacts engaged with hover tooltips
- **AI-Powered Insights**: Einstein AI generates 5 key insights and 5 actionable recommendations
- **Interactive Tooltips**: Every metric card reveals detailed breakdowns on hover

## How Scoring Works

All scoring is based on real-time queries against standard Salesforce objects. Activities (Tasks, Events, EmailMessages) and Opportunities are scoped to the **last 30 days**.

### Category Weights and Calculation

| Category | Weight | Data Sources | How It's Calculated |
|--------|--------|-------------|---------------------|
| **Activity Volume** | 30% | Tasks, Events, EmailMessages | Total activities (calls + emails + meetings + tasks): 100+ = 30 pts, 75+ = 25, 50+ = 20, 25+ = 15, 10+ = 10, 5+ = 5. |
| **Pipeline Health** | 25% | Opportunities, OpportunityFieldHistory | Pipeline value (15 pts): $1M+ = 15, $500K+ = 12, $250K+ = 10, $100K+ = 7, $50K+ = 5. Deal velocity (5 pts): 7d or less = 5, 14d = 4, 21d = 3, 30d = 2. At-risk deals (5 pts): 0 = 5, 1-2 = 3, 3-5 = 1, 6+ = -2. |
| **Deal Execution** | 25% | Opportunities | Win rate (15 pts): 50%+ = 15, 40%+ = 12, 30%+ = 10, 20%+ = 7, >0% = 5. Revenue (10 pts): $500K+ = 10, $250K+ = 8, $100K+ = 6, $50K+ = 4, >$0 = 2. |
| **Relationship Building** | 20% | Tasks, Events, Contacts | Contacts engaged (12 pts): 50+ = 12, 30+ = 10, 20+ = 8, 10+ = 6, 5+ = 4, >0 = 2. New relationships (8 pts): 10+ = 8, 5+ = 6, 3+ = 4, 1+ = 2. |

### Penalties

| Condition | Penalty |
|-----------|---------|
| 5+ stagnant deals (no stage change in 30+ days) | -5 pts |
| 3-5 stagnant deals | -2 pts |
| 5+ past-due close dates | -5 pts |
| 3-5 past-due close dates | -2 pts |

### Performance Status

| Score Range | Status |
|-------------|--------|
| 80-100 | Crushing It |
| 60-79 | On Target |
| 40-59 | Needs Attention |
| 0-39 | Struggling |

### Trend Analysis

The 30-day trend (Accelerating, Steady, or Declining) is determined by Einstein AI based on the seller's activity patterns, pipeline momentum, deal execution, and relationship building metrics.

## Components

### Lightning Web Component
- `sellerPerformance` — Single-component dashboard with circular score gauge, metric cards, pipeline health bar, deal velocity, AI insights, and recommended actions

### Apex Classes
- `SellerPerformanceController` — Main controller that queries user-related records, computes the weighted performance score, builds context for AI analysis, and parses AI responses
- `SellerPerformanceAnalysis` — Wrapper class for score, status, trend, insights, and recommended actions
- `SellerPerformanceMetrics` — Data wrapper class for all activity, pipeline, deal execution, and relationship metrics with tooltip data

### Additional Metadata
- `AgentforceRGBIcon.png` — Static resource used in the loading state

## Dependencies

- **Static Resources**: `AgentforceRGBIcon` (included in this repo)
- **Salesforce AI Platform**: Einstein Generative AI / Models API (required for AI insights and trend analysis)
- **Standard Objects**: User, Task, Event, EmailMessage, Opportunity, OpportunityFieldHistory, Contact, Account (no custom objects required)

## Installation

### Prerequisites
- A Salesforce org with API version 62.0+
- Einstein Generative AI enabled (required for AI insights and trend analysis)

### Deployment Steps

1. Clone this repository:
   ```bash
   git clone https://github.com/dylandersen/sellerPerformance.git
   ```
2. Deploy to your Salesforce org:
   ```bash
   sf project deploy start --source-dir force-app
   ```
3. Open any Lightning App Builder page (Home Page recommended) and drag the `sellerPerformance` component onto the page
4. Save and activate the page

### Einstein Generative AI
The AI insights feature uses the `sfdc_ai__DefaultOpenAIGPT4OmniMini` model. If your org uses a different model name, update the `modelName` value in `SellerPerformanceController.callEinsteinAI()`.

## Usage

1. Navigate to the page where you placed the `sellerPerformance` component
2. Click the sparkle button to let Agentforce analyze your performance
3. The performance score, metrics, pipeline health, and deal velocity compute automatically
4. Hover over any metric card for detailed breakdowns
5. Click the info icons on Health Assessment and 30-Day Trend for expandable detail panels
6. Review AI-generated Key Insights and Recommended Actions

## Known Limitations

- **30-day activity window is fixed** — Tasks, Events, EmailMessages, and Opportunities are always scoped to the last 30 days. This is not configurable.
- **AI model name is hardcoded** — The model `sfdc_ai__DefaultOpenAIGPT4OmniMini` is set in Apex. If your org provisions a different model, you'll need to update the class.
- **Current user only** — The component always analyzes the currently logged-in user. There is no user picker to analyze other sellers.
- **Deal velocity fallback** — If no stage transition history exists, velocity is estimated from closed-won deal durations or open deal age divided by an assumed 4 stages.
- **No custom objects required** — The app relies entirely on standard objects, but this means it cannot store historical scores without extending the data model.
- **OpportunityFieldHistory** — Deal velocity and stagnant deal detection require Field History Tracking enabled on the Opportunity StageName field.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Support

**No support is provided for this project.**

For non-support requests, please contact Dylan Andersen at dylan.andersen@salesforce.com.

**Author:** Dylan Andersen, Senior Solution Engineer, Agentforce at Salesforce
