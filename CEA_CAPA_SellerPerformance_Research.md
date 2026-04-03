# CEA CAPA Seller Performance Dashboard — Research & Recommendations

## Executive Summary

This document captures findings from a deep investigation of the CEA CAPA Salesforce Education Cloud org (`ceaPOC`), analyzing users, data model, opportunity pipeline, activity patterns, and existing dashboards/reports. The goal: redesign the generic Seller Performance LWC dashboard into something ultra-specific and valuable for CEA CAPA's Institutional Relations (IR) reps, Custom Programs managers, and sales leadership.

**The bottom line:** CEA CAPA's sales motion is fundamentally different from a traditional B2B sales org. Their "sellers" are IR reps who manage university partnerships, develop custom study abroad programs, and drive student enrollment. The existing generic dashboard — which relies heavily on call/email/meeting activity logging — will show almost nothing useful. We need to completely reframe the metrics around **partnership development**, **program pipeline**, **enrollment pacing**, and **institutional engagement**.

---

## 1. Business Context

### What CEA CAPA Does
CEA CAPA Education Abroad is a study abroad provider offering:
- **Standard Programs** — semester/summer study abroad at CEA CAPA centers worldwide
- **Custom Programs** — faculty-led or institution-specific study abroad trips
- **Internship Programs** — international internship placements (CIP)
- **Consulting Programs** — global business consulting experiences

### Destinations (20+ locations)
Argentina (Buenos Aires), Australia (Sydney), Costa Rica (San José), Czech Republic (Prague), England (London), France (Aix-en-Provence, Grenoble, Paris, French Riviera), Hungary (Budapest), Ireland (Dublin, Galway), Italy (Florence, Rome, Milan), Netherlands (Amsterdam), Spain (Alicante, Barcelona, Granada, Madrid, Seville), Japan (Tokyo), and more.

### How They Sell
CEA CAPA sells to **universities** (B2B), not directly to students. The sales cycle:
1. IR reps manage relationships with Home Institutions (universities)
2. They develop Account Strategies per institution per term
3. Custom programs are proposed, developed, and launched with specific university faculty
4. Students apply through their university's study abroad office
5. Revenue is driven by student enrollment volume × price per student

---

## 2. Org Users — The "Sellers"

### Institutional Relations Team (~35 active users)
These are the core "sellers" — the primary audience for this dashboard.

| Profile | Count | Key Users |
|---------|-------|-----------|
| **Institutional Relations** | 35 | Tom Durigan, Erin Pendle, Sean McCarthy, Rebecca James, Kira Rysiewicz, Matthew Borlik, Jon Jorgenson, Derek Shepard, Ashley Ganes, Seth Weil, Megan Reese, Amber Kettmann, Matthew Janus, Ben Briggs, Juan Cabrera Hurtado, Sara Fulmer, Sean Williams, Matthew Lawson, Bonnie Tarrant, Laura Madden, Kent Moore, Mary Alice Haas, Kyle Cox, James LaRue, Tim Boubek, Kelsey Eihausen, and others |
| **Custom Programs** | 3 | Andrew Solem (owns 11,966 Account Strategy opps), Lindsey Molusky, Hannah Parten |
| **Exec/Leadership** | 2 | Chris Dolan (IR), Kyle Simmons |

### User Role Hierarchy
Mostly flat. Key roles:
- `Institutional Relations User` (3 users)
- `Exec/Leadership User` (1 user — Chris Dolan)
- `Regional Director`, `Partnership Director`, `Vice President`, `Director` exist but few are assigned
- Most IR reps have **no UserRole assigned**

### Top Home Institution Account Owners
| Owner | # Accounts |
|-------|-----------|
| Andrew Solem | 1,647 |
| Kelsey Eihausen | 1,402 |
| Kyle Simmons | 879 |
| Yasamin Sharif | 777 |
| Jenn Rau | 35 |
| Seth Weil | 35 |
| Kira Rysiewicz | 31 |
| Kyle Cox | 19 |

---

## 3. Data Model — What Exists

### Account Record Types
| Record Type | Count | Purpose |
|-------------|-------|---------|
| **Home Institution** | 4,991 | Universities that send students (primary B2B accounts) |
| **Host Institution** | 123 | Partner universities abroad |
| **Person Account** | many | Students (not relevant for seller dashboard) |
| **Business Account** | 3 | Other B2B accounts |
| **CEA CAPA Faculty** | — | Faculty person accounts |
| **School of Record** | — | Schools providing academic credit |
| **Host Organization** | — | Internship host companies |
| **Competitor** | 1 | Competitive tracking |

### Opportunity Record Types
| Record Type | Count | Purpose |
|-------------|-------|---------|
| **Account Strategy** | ~17,715 | Institutional partnership agreements per term (the core B2B "deal") |
| **Custom** | ~2,311 | Custom faculty-led program proposals |
| **Cohort** | ~451 | Cohort/group programs |
| **Student Opportunity** | ~388,342 | Individual student enrollments (high volume, tracked separately) |
| **Non-Student Participant** | — | Non-student program participants |
| **Test** | — | Legacy/test records |

### Opportunity Stages (B2B Pipeline)
```
New → In Development → Proposal Sent → Qualified → Agreement Signed →
University Approved → Roster Received → Enrolled → Program Onsite →
Program Complete → Closed Won → Closed Won Archive
                  ↘ Closed Lost
                  ↘ Closed Did Not Pursue
                  ↘ Closed Lost - Did Not Launch
                  ↘ Pending Approval
```

### Key Custom Objects
| Object | Count | Purpose |
|--------|-------|---------|
| **Opportunity Group** (`Opportunity_Group__c`) | 451 | Groups related opps for a custom program deal |
| **Success Plan** (`Success_Plan__c`) | 215 | Account engagement plans for key institutions |
| **Request for Proposal** (`Request_For_Proposal__c`) | 333 | Custom program RFP tracking |
| **Program Offering** (`Program_Offering__c`) | many | Specific program offerings by destination/term |
| **Destination** (`Destination__c`) | ~25 | Study abroad destinations |
| **Program Offering Destination** | — | Junction between programs and destinations |
| **Product Interest** (`Product_Interest__c`) | 4 | Barely used |
| **Learning Program** | ~100+ | Standard and Custom learning programs |
| **Learner Program** | 11,702 | Student program enrollments |
| **Individual Application** | 33,000+ | Student applications (actively being created) |

### Opportunity Custom Fields (277 total — key categories)

**Enrollment Metrics:**
- `Active_Enrollment__c`, `Estimated_Enrollment__c`, `Forecasted_Students__c`
- `Minimum_Enrollment__c`, `Potential_Yearly_Enrollment__c`, `ProjectedEnrollment__c`, `BlendedEnrollment__c`

**Revenue & Pricing:**
- `Active_Revenue__c`, `ActiveRevenue__c`, `BlendedRevenue__c`, `Estimated_Revenue__c`
- `Forecasted_Revenue__c`, `ProjectedRevenue__c`, `Miscellaneous_Revenue__c`
- `ActiveMargin__c`, `ProjectedMargin__c`, `TargetMargin__c`
- `ActivePricePerStudent__c`, `ProjectedPricePerStudent__c`, `Target_Price_per_Student__c`

**Program Details:**
- `Academic_Term__c`, `Academic_Year__c`, `Term_Type__c`, `Semester__c`
- `Program_Type__c`, `Program_Sub_Type__c`, `Business_Type__c`, `Channel__c`
- `Opportunity_Destination__c`, `Start_Date__c`, `End_Date__c`

**Sales & Pipeline:**
- `Deal_Score__c`, `Opportunity_Score__c`, `Calculated_Priority__c`
- `Likelihood_to_Enroll__c`, `Likelihood_to_Win__c`, `Sales_Segment__c`

**Agreements:**
- `Agreement_Status__c`, `Date_Proposal_Sent__c`, `Date_Agreement_Signed__c`
- `Date_Addendum_Sent__c`, `Date_Addendum_Signed__c`

**Discounting:**
- `Discount_Amount__c`, `Discount_Type__c`, `Discounting_Status__c`
- `Scholarship_Amount__c`, `Flight_Credit_Amount__c`

**Relationship Lookups:**
- `Opportunity_Group__c`, `Success_Plan__c`, `IR_Opportunity__c`
- `Learning_Program__c`, `Request_For_Proposal__c`, `Program_Development_Project__c`

**Team Roles:**
- `CPM__c`, `PPM__c`, `Student_Advisor__c`, `Custom_Program_Developer__c`
- `Regional_VP__c`, `Exec_Sponsor__c`, `Partnership_Manager__c`

---

## 4. Critical Findings

### Finding 1: Activity Logging Is Essentially Non-Existent
| Activity Type | Last 90 Days |
|---------------|-------------|
| Events (total) | 8 |
| IR Meeting Events | 2 |
| Email Messages | 5 |
| IR Internal Tasks | ~140 (mostly Not Started) |
| Tasks (IR-owned) | Near zero |

**Impact:** The existing dashboard's Activity Volume category (calls, emails, meetings, tasks = 30% of score) will be almost entirely zero for every IR rep. This entire category needs to be replaced.

### Finding 2: Revenue on Opportunity.Amount Is Not Used
- Closed Won opps in the last 12 months: **$0 or null** revenue on Amount field
- Real revenue tracking uses custom fields: `Active_Revenue__c`, `Forecasted_Revenue__c`, `ProjectedRevenue__c`
- Historical revenue appears on "Closed Won Archive" stage opps (totaling ~$8.15M across all)
- **Impact:** The existing dashboard's revenue and pipeline value calculations (querying `Amount`) will return nothing useful.

### Finding 3: "Account Strategy" Opps Are Not Traditional Deals
- 17,715 Account Strategy opps, of which 16,870 are "Closed Won"
- Many are cloned per term per institution (e.g., "Northwestern University Default Agreement Spring 2026 Cloned")
- They represent institutional partnership agreements, not individual revenue deals
- **Impact:** Win rate calculations on Account Strategy opps are meaningless in a traditional sales context.

### Finding 4: Enrollment Is the True North Star Metric
- Student Opportunity volume: 388,342 opps (386,115 in "Student" stage)
- The real business metric is **how many students each IR rep's institutions send per term**
- Custom fields like `Forecasted_Students__c`, `Active_Enrollment__c`, and `Estimated_Enrollment__c` are the real KPIs
- **Impact:** The dashboard needs to center on enrollment pacing, not deal count or dollar amounts.

### Finding 5: The Custom Program Pipeline Is the Active Sales Motion
- 2,311 Custom program opps with a full sales cycle
- Stages: New → In Development → Proposal Sent → Qualified → ... → Closed Won
- These are the "real deals" that IR reps actively work
- Linked to Opportunity Groups (451), RFPs (333), and Success Plans (215)
- **Impact:** Custom program pipeline health is the most valuable "Pipeline Health" metric.

### Finding 6: Existing Dashboards Focus on Revenue & Pacing
- Dashboard `01ZVS000002E5Q52AK`: "Spring 2026 Revenue & Pacing" (AHG revenue and pacing)
  - Folder: x_2026 Dashboards
  - Also a Derek Shepard-personalized version
- Report `00OVS000005mYpK2AU`: "IR Active Pipeline / Pipeline Mgmt"
  - In Public Reports
- Other reports: Apps Started, Closed Won, Standard Students, Standard Forecast, Leads, Institution-specific pacing (MSU, UMich)

### Finding 7: Campaign & Event Activity Is Seller-Relevant
- 268 IR Event campaigns (university visits, fairs, presentations)
- Marketing campaigns: 969 (Digital, Non-Digital, Fair, Info Table, Presentation)
- Campaign Member engagement: 14,032 members
- This is a better proxy for "seller activity" than call/email logging

---

## 5. Recommended Dashboard Redesign

### New Scoring Categories (replacing the generic model)

| Category | Weight | Replaces | Rationale |
|----------|--------|----------|-----------|
| **Enrollment Pacing** | 30 pts | Activity Volume (30 pts) | Enrollment is the #1 KPI; tracks forecasted vs actual student enrollment for the rep's institutions |
| **Program Pipeline** | 25 pts | Pipeline Health (25 pts) | Custom + Cohort program pipeline health; stage progression, stagnant deals, conversion |
| **Partnership Development** | 25 pts | Deal Execution (25 pts) | Account Strategy health; new agreements, proposals sent, programs launched, win rate on Custom opps |
| **Institutional Engagement** | 20 pts | Relationship Building (20 pts) | Success Plans, RFPs, Opportunity Groups, Campaign participation, new institution relationships |

---

### Category 1: Enrollment Pacing (30 pts)

**Metric Cards:**
| Metric | Source | Display |
|--------|--------|---------|
| **Forecasted Students** | `SUM(Forecasted_Students__c)` on Account Strategy/Custom opps owned by user for current/next term | Number + trend |
| **Active Enrollment** | `SUM(Active_Enrollment__c)` on opps for current term | Number + % of forecast |
| **Enrollment Pacing %** | Active ÷ Forecasted × 100 | Gauge (red/yellow/green) |
| **Apps Started** | `COUNT(IndividualApplication)` linked to user's institutions, current term | Number + trend |
| **YoY Enrollment Change** | Compare current term enrollment to same term prior year | % change with arrow |
| **Forecasted Revenue** | `SUM(Forecasted_Revenue__c)` or `SUM(ProjectedRevenue__c)` | Currency formatted |

**Scoring Logic:**
- Enrollment Pacing ≥ 100%: 15/15 pts
- Pacing 80-99%: 12/15 pts
- Pacing 60-79%: 8/15 pts
- Pacing < 60%: 4/15 pts
- Apps Started vs. target: up to 10 pts
- YoY growth positive: +5 pts / flat: +3 pts / negative: +0 pts

---

### Category 2: Program Pipeline (25 pts)

**Metric Cards:**
| Metric | Source | Display |
|--------|--------|---------|
| **Open Custom Programs** | `COUNT(Opportunity)` WHERE RecordType = 'Custom' AND IsClosed = false AND OwnerId = :userId | Number by stage |
| **Open Cohort Programs** | `COUNT(Opportunity)` WHERE RecordType = 'Cohort' AND IsClosed = false | Number |
| **Pipeline by Stage** | Stage distribution bar chart (New, In Dev, Proposal Sent, etc.) | Horizontal stacked bar |
| **Programs Won (Last 12mo)** | Closed Won Custom + Cohort opps | Number |
| **Programs Lost/DNP** | Closed Lost + Did Not Pursue | Number |
| **Custom Program Win Rate** | Won ÷ (Won + Lost + DNP) for Custom opps | Percentage |
| **Stagnant Programs** | Custom/Cohort opps with no stage change in 30+ days | Number (red if >3) |
| **Avg Time to Launch** | Average days from New → Program Onsite for Custom opps | Days |

**Scoring Logic:**
- Pipeline has 5+ open programs in active stages: 8/8 pts
- Win rate > 50%: 7/7 pts
- No stagnant programs: 5/5 pts
- Time to launch trending down: 5/5 pts

---

### Category 3: Partnership Development (25 pts)

**Metric Cards:**
| Metric | Source | Display |
|--------|--------|---------|
| **Account Strategies (Active)** | Account Strategy opps in non-closed stages owned by user | Number |
| **Proposals Sent** | Opps with `Date_Proposal_Sent__c` in last 90 days | Number |
| **Agreements Signed** | Opps with `Date_Agreement_Signed__c` in last 90 days | Number |
| **New Agreements (This Term)** | Account Strategy opps created for current term | Number |
| **Revenue per Student** | `AVG(ActivePricePerStudent__c)` on user's opps | Currency |
| **Projected Revenue** | `SUM(ProjectedRevenue__c)` on user's open pipeline | Currency |
| **Margin Health** | `AVG(ActiveMargin__c)` or `AVG(ProjectedMargin__c)` | Percentage |
| **Discount Rate** | Avg discount amount on user's opps | Currency + % |

**Scoring Logic:**
- Proposals sent > 3 in 90 days: 8/8 pts
- Agreements signed > 2 in 90 days: 7/7 pts
- Revenue per student at or above target: 5/5 pts
- Margin health ≥ target: 5/5 pts

---

### Category 4: Institutional Engagement (20 pts)

**Metric Cards:**
| Metric | Source | Display |
|--------|--------|---------|
| **Success Plans Active** | `COUNT(Success_Plan__c)` owned by user with active status | Number |
| **RFPs Submitted** | `COUNT(Request_For_Proposal__c)` owned by user in last 90 days | Number |
| **Opportunity Groups** | `COUNT(Opportunity_Group__c)` owned by user | Number |
| **IR Events Participated** | Campaigns with RecordType = 'IR Event' where user has CampaignMembers | Number |
| **Home Institutions Managed** | `COUNT(Account)` WHERE RecordType = 'Home Institution' AND OwnerId = :userId | Number |
| **New Institutional Contacts** | New contacts created at user's Home Institutions in last 90 days | Number |
| **Site Visits** | `COUNT(site_visit_request__c)` related to user's accounts | Number |

**Scoring Logic:**
- Success Plans active ≥ 5: 6/6 pts
- RFPs submitted ≥ 3: 5/5 pts
- Opportunity Groups managed ≥ 3: 4/4 pts
- IR Event participation ≥ 2: 3/3 pts
- Active institutional contacts growing: 2/2 pts

---

### Health Overview Section (Top of Dashboard)

| Panel | Content |
|-------|---------|
| **Score Gauge** | 0-100 circular gauge (same visual, new scoring) |
| **Enrollment Pacing** | Mini gauge — forecasted vs actual enrollment % |
| **Program Pipeline Health** | Stacked bar — programs by stage (replaces generic healthy/at-risk bar) |
| **Term Comparison** | Current term vs prior year same term — enrollment + revenue delta |

### AI-Generated Insights (Agentforce Section)

The context sent to Einstein AI should include:
1. Enrollment pacing % and gap to forecast
2. Which institutions are pacing above/below target
3. Custom program pipeline status and any stagnant programs
4. Recently signed agreements and proposals outstanding
5. Success plan activity
6. Comparison to team averages (if running as leadership)
7. Term-over-term enrollment trends

Prompt the AI to generate:
- **Trend**: "Enrollment Accelerating" / "Pacing On Track" / "Enrollment Declining"
- **Key Insights**: 5 bullets specific to the rep's portfolio (e.g., "University of Delaware has 3 active custom programs in development — strongest pipeline in your territory")
- **Recommended Actions**: 5 actionable items (e.g., "Follow up on SUNY Oneonta Atlantis proposal — sent 4 months ago, no stage change")

---

## 6. SOQL Queries to Build

### Enrollment Pacing
```sql
-- Forecasted vs Active enrollment for running user's institutions
SELECT Account.Name, SUM(Forecasted_Students__c) forecasted,
       SUM(Active_Enrollment__c) active, SUM(Active_Revenue__c) revenue
FROM Opportunity
WHERE OwnerId = :userId
  AND RecordType.Name = 'Account Strategy'
  AND Academic_Term__c = :currentTerm
GROUP BY Account.Name
ORDER BY SUM(Forecasted_Students__c) DESC NULLS LAST

-- Apps started for user's institutions
SELECT COUNT(Id) appCount
FROM IndividualApplication
WHERE Account.OwnerId = :userId
  AND CreatedDate = THIS_FISCAL_QUARTER
```

### Program Pipeline
```sql
-- Open Custom + Cohort pipeline
SELECT RecordType.Name, StageName, COUNT(Id) numOpps,
       SUM(Forecasted_Students__c) students, SUM(ProjectedRevenue__c) revenue
FROM Opportunity
WHERE OwnerId = :userId
  AND RecordType.Name IN ('Custom', 'Cohort')
  AND IsClosed = false
GROUP BY RecordType.Name, StageName

-- Stagnant programs (no stage change in 30 days)
SELECT Id, Name, StageName, LastModifiedDate, Account.Name
FROM Opportunity
WHERE OwnerId = :userId
  AND RecordType.Name IN ('Custom', 'Cohort')
  AND IsClosed = false
  AND LastModifiedDate < LAST_N_DAYS:30
```

### Partnership Development
```sql
-- Proposals and agreements
SELECT COUNT(Id) proposalsSent
FROM Opportunity
WHERE OwnerId = :userId
  AND Date_Proposal_Sent__c = LAST_N_DAYS:90

SELECT COUNT(Id) agreementsSigned
FROM Opportunity
WHERE OwnerId = :userId
  AND Date_Agreement_Signed__c = LAST_N_DAYS:90

-- Revenue and margin
SELECT AVG(ActivePricePerStudent__c) avgPricePerStudent,
       AVG(ActiveMargin__c) avgMargin,
       SUM(ProjectedRevenue__c) totalProjectedRevenue
FROM Opportunity
WHERE OwnerId = :userId
  AND RecordType.Name IN ('Account Strategy', 'Custom')
  AND IsClosed = false
```

### Institutional Engagement
```sql
-- Success Plans
SELECT COUNT(Id) activePlans FROM Success_Plan__c WHERE OwnerId = :userId

-- RFPs
SELECT COUNT(Id) rfpCount FROM Request_For_Proposal__c
WHERE OwnerId = :userId AND CreatedDate = LAST_N_DAYS:90

-- Opportunity Groups
SELECT COUNT(Id) oppGroups FROM Opportunity_Group__c WHERE OwnerId = :userId

-- Home Institutions managed
SELECT COUNT(Id) numInstitutions FROM Account
WHERE OwnerId = :userId AND RecordType.Name = 'Home Institution'
```

---

## 7. Implementation Plan

### Phase 1: Core Metrics (Apex Controller Rewrite)
1. Replace `gatherMetrics()` with CEA CAPA-specific queries
2. Update `SellerPerformanceMetrics` DTO with new fields (enrollment, programs, partnerships, engagement)
3. Update `calculatePerformanceScore()` with the new 4-category weighted scoring
4. Update `buildContextData()` to provide CEA CAPA-specific context to Einstein AI

### Phase 2: LWC Visual Redesign
1. Replace the 8 metric cards with CEA CAPA-specific metrics
2. Replace "Pipeline Health" bar with Program Pipeline by Stage stacked bar
3. Replace "Deal Velocity" badge with Enrollment Pacing gauge
4. Add Term Comparison panel (current vs prior year)
5. Update color scheme to match CEA CAPA brand (consider their blue/green palette from ceacapa.com)

### Phase 3: AI Prompt Engineering
1. Rewrite the Einstein AI prompt to understand study abroad context
2. Include enrollment pacing data, program pipeline, and institutional relationships
3. Generate institution-specific insights (e.g., "Arizona State is pacing 20% behind forecast")
4. Generate seasonal/term-aware recommendations

### Phase 4: Leadership View (Stretch)
1. If running user has a leadership profile/role, show team-level aggregation
2. Team enrollment pacing leaderboard
3. Territory-level pipeline summary
4. Regional comparison

---

## 8. Key Risk: Data Quality

| Issue | Severity | Mitigation |
|-------|----------|------------|
| `Amount` field is not populated | High | Use `Active_Revenue__c`, `Forecasted_Revenue__c`, `ProjectedRevenue__c` instead |
| Activity logging is near zero | High | Don't score on activity; focus on outcomes (enrollment, programs, agreements) |
| Many Account Strategy opps are cloned templates | Medium | Filter on meaningful stages; exclude bulk-cloned "New" stage records or use `LastModifiedDate` |
| `Forecasted_Students__c` may be null on many records | Medium | Fall back to `Estimated_Enrollment__c` → `Potential_Yearly_Enrollment__c` |
| Role hierarchy is flat | Low | Use Profile name to determine if user is leadership vs. individual contributor |
| Student Opportunities are 388K+ records | High | Never query Student Opportunity record type in aggregate without strict filters |

---

## 9. Objects & Fields Quick Reference

### Must-Query Objects
| Object | Key Fields | Why |
|--------|------------|-----|
| `Opportunity` (Account Strategy) | `Forecasted_Students__c`, `Active_Enrollment__c`, `Active_Revenue__c`, `ProjectedRevenue__c`, `Date_Proposal_Sent__c`, `Date_Agreement_Signed__c`, `Academic_Term__c` | Core enrollment & partnership metrics |
| `Opportunity` (Custom) | `StageName`, `Start_Date__c`, `Forecasted_Students__c`, `ProjectedRevenue__c`, `ActiveMargin__c` | Program pipeline |
| `Opportunity` (Cohort) | Same as Custom | Program pipeline |
| `Success_Plan__c` | `OwnerId`, `Name` | Engagement metric |
| `Request_For_Proposal__c` | `OwnerId`, `RecordType.Name`, `CreatedDate` | Engagement metric |
| `Opportunity_Group__c` | `OwnerId`, `Name` | Engagement metric |
| `Account` (Home Institution) | `OwnerId`, `Name` | Portfolio size |
| `IndividualApplication` | `CreatedDate`, parent account | Apps started pacing |
| `Campaign` (IR Event) | Members, participation | Engagement metric |
| `User` | `Profile.Name`, `UserRole.Name` | Determine dashboard mode (IC vs leader) |

### Fields That Replaced Standard Amount
| Custom Field | Purpose |
|-------------|---------|
| `Active_Revenue__c` / `ActiveRevenue__c` | Current actual revenue |
| `Forecasted_Revenue__c` | Revenue forecast |
| `ProjectedRevenue__c` | Projected revenue |
| `BlendedRevenue__c` | Blended revenue calculation |
| `Estimated_Revenue__c` | Estimated revenue |
| `ActivePricePerStudent__c` | Revenue per student |
| `ProjectedPricePerStudent__c` | Projected price per student |
| `ActiveMargin__c` | Current margin |
| `ProjectedMargin__c` | Projected margin |

---

## 10. Existing Dashboard Reference

### Dashboard: Spring 2026 Revenue & Pacing (`01ZVS000002E5Q52AK`)
- **Folder:** x_2026 Dashboards
- **Description:** AHG revenue and pacing
- **Components visible in screenshot:**
  - Spring '26 Apps (by Student Status — bar chart)
  - Forecasting Spring 2026 Standard (donut chart — $1.5K forecast by owner)
  - Forecasting SP26 Standard > 1bd (donut chart — 400 records by owner)
  - 2026 Custom Forecast (bar chart — High/Med/Best/Omitted by term)
  - CP Forecast Outdated 30d (donut chart — $6.3M by institution)
  - Atlantis Opportunities v3 (horizontal bar — by institution)
  - Account Strategies - Growth Pipeline (stacked bar by stage/term)
  - Custom Programs Revenue Pipeline (bar — Std/Blended Revenue)
  - Enrollment Pacing Burn by Term (bar chart)
  - Assigned Accounts (donut — 3.3K by owner)
  - New Standard Opps Last 30 Days (metric — 3)
  - IR Account Strategies Outdated (table — amounts by institution)
  - CP Dev Active Development Pipeline IR (bar — by development stage)
  - New CP Opps Last 30 Days (metric — 1)

### Report: IR Active Pipeline (`00OVS000005mYpK2AU`)
- **Folder:** Public Reports
- **Developer Name:** IR_Active_Pipeline_Pipeline_Mgmt
- **Purpose:** Active pipeline management for IR team

### Other Relevant Reports (2026 Pacing Reports folder)
- `Apps_Started_Report`
- `Closed_Won_Report`
- `SP26_Standard_Forecast`
- `SP26_Standard_Students`
- `Leads_2026`
- `MSU_Apps_Started` / `UMich_Apps_Started` (institution-specific)

---

## 11. Summary of Changes Required

| Existing Dashboard Element | CEA CAPA Replacement |
|----------------------------|---------------------|
| Activity Volume (30pts): Calls, Emails, Meetings, Tasks | **Enrollment Pacing (30pts):** Forecasted Students, Active Enrollment, Pacing %, Apps Started, YoY Change, Forecasted Revenue |
| Pipeline Health (25pts): Pipeline Value, Deal Velocity, At-Risk Deals | **Program Pipeline (25pts):** Open Custom/Cohort Programs, Stage Distribution, Win Rate, Stagnant Programs, Time to Launch |
| Deal Execution (25pts): Win Rate, Revenue, Avg Deal Size | **Partnership Development (25pts):** Active Account Strategies, Proposals Sent, Agreements Signed, Revenue per Student, Projected Revenue, Margin Health |
| Relationship Building (20pts): Contacts Engaged, New Relationships | **Institutional Engagement (20pts):** Success Plans, RFPs, Opportunity Groups, IR Events, Home Institutions, New Contacts, Site Visits |
| Pipeline Health Bar (Healthy vs At-Risk) | **Program Pipeline by Stage** (stacked bar: New / In Dev / Proposal / Agreement / etc.) |
| Deal Velocity (days) | **Enrollment Pacing Gauge** (% of forecast achieved) |
| 8 Metric Cards | **8 New Metric Cards** mapped to CEA CAPA KPIs |
| AI Context (generic sales) | **AI Context** (study abroad specific: enrollment, institutions, programs, term pacing) |

---

*Generated: April 2, 2026*
*Org: ceaPOC (CEA CAPA Education Cloud)*
*Dashboard Target: Seller Performance LWC — Education Cloud Edition*
