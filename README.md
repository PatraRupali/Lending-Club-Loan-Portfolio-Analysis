# 🏦 Lending Club Loan Portfolio Analysis

[![MySQL](https://img.shields.io/badge/MySQL-8.0-blue)](https://www.mysql.com/)
[![PowerBI](https://img.shields.io/badge/Power%20BI-Dashboard-yellow)](https://powerbi.microsoft.com/)
[![Domain](https://img.shields.io/badge/Domain-Banking%20%26%20Financial%20Services-green)]()
[![Status](https://img.shields.io/badge/Status-Completed-success)]()

**Domain** · Banking & Financial Services | Credit Risk | MIS Reporting  
**Tools** · MySQL 8.0 · Power BI  
**Dataset** · 1,048,575 loan records · 16 columns · $16.13B portfolio value  
**Source** · Lending Club (2007–2015) via Kaggle  
**Author** · Rupali Patra

---

## 📌 Project Overview

This project simulates end-to-end loan portfolio analysis work performed by a banking data analyst — covering data quality validation, data cleaning, portfolio health monitoring, NPA/default identification, borrower risk scoring, income segmentation, geographic concentration analysis, and executive reporting.

The project follows a complete professional pipeline:

```
Raw Data → Data Quality Checks → Data Cleaning → SQL Analysis → Power BI Dashboard
```

---

## 📂 Project Structure

```
Lending-Club-Loan-Portfolio-Analysis/
│
├── Lending_Club_Complete_Project_Final.sql   ← Complete pipeline (DQ + Cleaning + Analysis)
├── Loan_Portfolio_Project_Showcase.pdf       ← Query outputs with business insights
└── README.md                                 ← This file
```

---

## 🗃️ Dataset Schema

| Column | Type | Description |
|---|---|---|
| `loan_amnt` | DECIMAL | Loan amount disbursed |
| `term` | VARCHAR | Loan tenure — 36 or 60 months |
| `int_rate` | DECIMAL | Annual interest rate (%) |
| `installment` | DECIMAL | Monthly EMI payment |
| `grade` | VARCHAR | Credit grade (A=safest → G=riskiest) |
| `sub_grade` | VARCHAR | Sub-grade within grade |
| `emp_length` | VARCHAR | Borrower employment tenure |
| `home_ownership` | VARCHAR | OWN / MORTGAGE / RENT |
| `annual_inc` | DECIMAL | Borrower annual income |
| `verification_status` | VARCHAR | Income verification status |
| `loan_status` | VARCHAR | Current / Fully Paid / Charged Off / Late |
| `purpose` | VARCHAR | Declared reason for borrowing |
| `addr_state` | VARCHAR | US state of borrower |
| `dti` | DECIMAL | Debt-to-Income ratio (%) |
| `revol_util` | DECIMAL | Credit utilisation % |
| `total_pymnt` | DECIMAL | Total amount collected from borrower |

---

## 📊 Analytical Sections

| Section | Queries | Focus Area |
|---|---|---|
| **0A** · Data Quality Checks | DQ1–DQ9 | Validate raw data before analysis |
| **0B** · Data Cleaning | VIEW | Fix 12 issues — create loans_clean |
| **A** · Portfolio Overview | A1, A2, A3 | KPI dashboard, term split, purpose analysis |
| **B** · Default & Risk | B1, B2, B3 | Grade risk, ownership impact, DTI bucketing |
| **C** · Income & Affordability | C1, C2 | Income segmentation, employment stability |
| **D** · Advanced Analytics | D1–D6 | Window functions, CTEs, risk scoring model |
| **E** · Executive Report | E1 | Management-ready one-page summary |

---

## ✅ Data Quality Findings

| Check | Finding | Action |
|---|---|---|
| DQ1 Row Count | 1,048,575 rows loaded ✅ | None |
| DQ2 Duplicates | 1,158 duplicate groups (0.22%) | Noted — negligible |
| DQ3 NULLs | Zero NULLs in critical columns ✅ | None |
| DQ4 Loan Status | 7 clean standard categories ✅ | None |
| DQ5 Outliers | DTI max=999 · income max=$9.93M · revol_util max=191% | Fixed in VIEW |
| DQ6 Grade | All 7 grades A–G · risk_category populated ✅ | None |
| DQ7 emp_length | 77,465 'n/a' values (7.4%) | Relabelled → 'Not Specified' |
| DQ8 Geographic | All 50 states · min 2,101 loans per state ✅ | None |
| DQ9 Summary | **Data Quality Score = 99.4%** ✅ | 12 issues fixed in cleaning |

---

## 🧹 Data Cleaning — loans_clean VIEW

All analysis runs on `loans_clean` — raw `loans` table preserved untouched.

| Fix | Issue | Rows Affected |
|---|---|---|
| TRIM(term) | Leading space in every row | 1,048,575 |
| emp_length 'n/a' → 'Not Specified' | Non-standard missing value | 77,465 |
| home_ownership 'ANY' → 'OTHER' | Non-standard category | 599 |
| annual_inc = 0 → NULL | Zero income is data error | 1,174 |
| annual_inc > $500K → capped | Extreme outlier (max $9.93M) | 1,869 |
| dti < 0 → NULL | Negative DTI impossible | 1 |
| dti > 100 → NULL | Data entry error (max=999) | 1,711 |
| revol_util > 100% → NULL | Impossible value (max=191%) | 3,153 |
| purpose 'wedding' → 'other' | Only 7 rows — not meaningful | 7 |

---

## 🔑 Key Findings

### A. Portfolio Overview
- Total portfolio: **$16.13 billion** across **1,048,575 loans**
- Average loan size: **$15,385** at **12.80%** average interest rate
- Overall risk rate: **10.15%** — 94,286 charged off + 14,316 late payments
- **36-month loans** dominate at 71.4% but 60-month loans default 35% more (11.02% vs 8.18%)
- **Debt consolidation** = 55% of volume · **Small business** = highest default (14.00%)

### B. Default & Risk Analysis
- **Grade G** borrowers default at **40.76%** — **17x higher** than Grade A (2.22%)
- **MORTGAGE** holders = safest (7.62% default) · **RENT** = riskiest (10.64%)
- **Very High DTI (>30%)** borrowers default at 11.77% — **1.8x** Low DTI borrowers (6.55%)

### C. Income & Affordability
- Clear income-risk relationship: **Above $150K = 5.98% default** · **Below $40K = 10.58%**
- Employment length is a **weak predictor** — 'Not Specified' group has highest default (10.84%)
- Credit utilisation consistent across all employment groups (43–49%)

### D. Advanced Analytics
- **Top 5 states** (CA, TX, NY, FL, IL) account for **41.8%** of total portfolio value
- **SUBPRIME** borrowers default at **16.42%** — **3.7x** higher than PRIME (4.46%)
- **Arkansas** = highest default state at **10.98%** · Top 5 riskiest = all Southern/Midwestern
- Grade cliff identified: **E→F jump = +11.09%** default — largest single-step risk increase
- **Q2 Medium Loans ($8K–$15K)** = largest segment (341,535 loans)

---

## 🛠️ SQL Techniques Used

| Technique | Used In | Purpose |
|---|---|---|
| `COUNT(CASE WHEN ... THEN 1 END)` | All sections | Conditional aggregation — single scan |
| `SUM() OVER()` | A2, A3, C1, D2, D3 | Portfolio share without scalar subquery |
| `SUM() OVER (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)` | D2 | Running cumulative total |
| `RANK() OVER (ORDER BY ...)` | D1 | Risk ranking with tie handling |
| `DENSE_RANK() OVER (ORDER BY ...)` | D4 | Geographic risk leaderboard — no rank gaps |
| `LAG() OVER (ORDER BY ...)` | D5 | Period-over-period delta comparison |
| Two-level CTE | D3 | Score borrowers on 4 factors |
| Three-level CTE | D3 | Score → Segment → Summarise pipeline |
| `CREATE VIEW` | Section 0B | Data cleaning — raw data preserved |
| `UNION ALL` | E1 | Formatted management report |
| `HAVING COUNT(*) >= 50` | D4 | Statistical significance filter |
| `TRIM()` in GROUP BY | A2 | Dirty data handling |
| `COALESCE` + `CASE WHEN` | Section 0B | NULL and 'n/a' handling |

---

## 📈 Power BI Dashboard *(In Progress)*

Connecting the SQL analysis to an interactive Power BI report with the following visuals:

| Visual | Data Source | Insight |
|---|---|---|
| KPI Cards | A1 — portfolio_kpis | Total loans, portfolio value, risk rate |
| Bar Chart | B1 — grade_summary | Default rate by credit grade A→G |
| Filled Map | D4 — state_risk | Geographic default concentration |
| Donut Chart | D3 — segment_summary | PRIME / NEAR PRIME / SUBPRIME split |
| Line Chart | D5 — grade_rates | Rate jump and default cliff by grade |
| Stacked Bar | B3 — dti_buckets | DTI bucket vs default rate |
| Matrix Table | E1 — portfolio_stats | Executive summary report |

> 🔗 Dashboard link will be added here upon completion

---

## ⚙️ How to Run

```sql
-- Step 1: Create database
CREATE DATABASE IF NOT EXISTS lending_analysis;
USE lending_analysis;

-- Step 2: Import dataset
-- MySQL Workbench → Table Data Import Wizard → loan.csv
-- OR use LOAD DATA INFILE for large files

-- Step 3: Run complete pipeline
-- Open Lending_Club_Complete_Project_Final.sql
-- Press Ctrl + Shift + Enter
-- Sections run top to bottom automatically
```

**MySQL version required:** 8.0+ (window functions + CTEs)

---

## 💡 Business Value

| Business Function | How This Project Helps |
|---|---|
| **Credit Policy** | Grade G and DTI>30% thresholds for approval decisions |
| **Risk Management** | NPA identification · geographic concentration limits |
| **Pricing Strategy** | Grade-over-grade rate cliff analysis (D5) |
| **Customer Segmentation** | PRIME / NEAR PRIME / SUBPRIME classification (D3) |
| **MIS Reporting** | Executive one-page portfolio health report (E1) |
| **Underwriting** | Income band and home ownership benchmarks |

---

## 👩‍💻 Author

**Rupali Patra**  
Data Analyst · Banking & Financial Services Domain  
📧 rupalipatra1994@gmail.com  
🔗 [GitHub](https://github.com/RupaliPatra/loan-portfolio-analysis)  
🔗 [LinkedIn](https://linkedin.com/in/rupalipatra)

---

*This project demonstrates production-grade SQL analytics skills in the banking and financial services domain — from raw data validation through to executive reporting and interactive dashboards.*
