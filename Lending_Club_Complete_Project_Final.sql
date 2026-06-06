-- ============================================================================================================================
--  PROJECT      : Lending Club Loan Portfolio Analysis
--  AUTHOR       : Rupali Patra
--  DOMAIN       : Banking & Financial Services | Credit Risk | MIS Reporting
--  TOOLS        : MySQL 8.0 | Power BI
--  DATASET      : 1,048,575 Loan Records | 16 Columns | $16.13B Portfolio | Lending Club 2007–2015
--  SOURCE       : Lending Club via Kaggle
--  DATE         : 2024
-- ----------------------------------------------------------------------------------------------------------------------------
--  FILE STRUCTURE :
--
--    SECTION 0A  : Data Quality Checks     — inspect raw data (DQ1–DQ9)
--    SECTION 0B  : Data Cleaning           — fix all issues, create loans_clean view
--    SECTION A   : Portfolio Overview      — KPIs, term split, purpose analysis
--    SECTION B   : Default & Risk          — grade risk, home ownership, DTI buckets
--    SECTION C   : Income & Affordability  — income bands, employment stability
--    SECTION D   : Advanced Analytics      — window functions, CTEs, risk scoring
--    SECTION E   : Executive Report        — management-ready summary
-- ============================================================================================================================

USE lending_analysis;

-- ============================================================================================================================
-- INDEX SETUP  |  Run once only. If you get "Duplicate key name" error on re-run, skip these two lines.
-- ============================================================================================================================
CREATE INDEX idx_loan_status ON loans(loan_status);
CREATE INDEX idx_grade       ON loans(grade);


-- ============================================================================================================================
-- SECTION 0A : DATA QUALITY CHECKS
-- Purpose    : Inspect raw data BEFORE any cleaning or analysis
--              Identifies all problems so cleaning decisions are data-driven
--              Run Section 0A first — review outputs — then proceed to 0B
-- ============================================================================================================================

-- ----------------------------------------------------------------------------------------------------------------------------
-- DQ1  |  Row Count & Basic Sanity Check
-- Question   : Did the data load correctly? Are row counts and value ranges sensible?
-- ----------------------------------------------------------------------------------------------------------------------------
SELECT
    COUNT(*)                                    AS total_rows,
    COUNT(DISTINCT loan_amnt)                   AS unique_loan_amounts,
    MIN(loan_amnt)                              AS min_loan_amount,
    MAX(loan_amnt)                              AS max_loan_amount,
    MIN(int_rate)                               AS min_interest_rate,
    MAX(int_rate)                               AS max_interest_rate
FROM loans;


-- ----------------------------------------------------------------------------------------------------------------------------
-- DQ2  |  Duplicate Row Detection
-- Question   : Does any loan appear more than once in the table?
-- Finding    : 1,158 duplicate groups (2,360 rows = 0.22%) found — negligible impact
-- ----------------------------------------------------------------------------------------------------------------------------
WITH duplicate_check AS (
    SELECT
        loan_amnt, term, installment, annual_inc, dti,
        COUNT(*)                                AS occurrence_count
    FROM loans
    GROUP BY loan_amnt, term, installment, annual_inc, dti
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*)                                    AS total_duplicate_groups,
    COALESCE(SUM(occurrence_count), 0)          AS total_duplicate_rows
FROM duplicate_check;


-- ----------------------------------------------------------------------------------------------------------------------------
-- DQ3  |  NULL Value Analysis — All Critical Columns
-- Question   : Which columns have missing data and how bad is it?
-- Finding    : Zero NULLs — emp_length stored as 'n/a' string (77,465 rows = 7.4%)
-- ----------------------------------------------------------------------------------------------------------------------------
SELECT
    column_name,
    null_count,
    CONCAT(ROUND(null_count * 100.0 / total_rows, 2), '%') AS null_pct,
    CASE
        WHEN null_count * 100.0 / total_rows > 5  THEN '⚠️  High — needs fixing'
        WHEN null_count * 100.0 / total_rows > 0  THEN '⚠️  Low  — monitor'
        ELSE                                            '✅ Clean'
    END                                         AS verdict
FROM (
    SELECT 'loan_amnt'      AS column_name, COUNT(*) - COUNT(loan_amnt)      AS null_count, COUNT(*) AS total_rows FROM loans UNION ALL
    SELECT 'term',                          COUNT(*) - COUNT(term),           COUNT(*) FROM loans UNION ALL
    SELECT 'int_rate',                      COUNT(*) - COUNT(int_rate),       COUNT(*) FROM loans UNION ALL
    SELECT 'grade',                         COUNT(*) - COUNT(grade),          COUNT(*) FROM loans UNION ALL
    SELECT 'emp_length',                    COUNT(*) - COUNT(emp_length),     COUNT(*) FROM loans UNION ALL
    SELECT 'home_ownership',                COUNT(*) - COUNT(home_ownership), COUNT(*) FROM loans UNION ALL
    SELECT 'annual_inc',                    COUNT(*) - COUNT(annual_inc),     COUNT(*) FROM loans UNION ALL
    SELECT 'loan_status',                   COUNT(*) - COUNT(loan_status),    COUNT(*) FROM loans UNION ALL
    SELECT 'purpose',                       COUNT(*) - COUNT(purpose),        COUNT(*) FROM loans UNION ALL
    SELECT 'addr_state',                    COUNT(*) - COUNT(addr_state),     COUNT(*) FROM loans UNION ALL
    SELECT 'dti',                           COUNT(*) - COUNT(dti),            COUNT(*) FROM loans UNION ALL
    SELECT 'revol_util',                    COUNT(*) - COUNT(revol_util),     COUNT(*) FROM loans UNION ALL
    SELECT 'total_pymnt',                   COUNT(*) - COUNT(total_pymnt),    COUNT(*) FROM loans
) AS null_audit
ORDER BY null_count DESC;


-- ----------------------------------------------------------------------------------------------------------------------------
-- DQ4  |  Loan Status Distribution
-- Question   : Are all loan_status values valid? Any typos or unexpected categories?
-- Finding    : 7 clean statuses — Current 57.53%, Fully Paid 31.62%, Charged Off 8.99%
-- ----------------------------------------------------------------------------------------------------------------------------
SELECT
    loan_status,
    COUNT(*)                                    AS record_count,
    CONCAT(ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER(), 2), '%')          AS percentage
FROM loans
GROUP BY loan_status
ORDER BY record_count DESC;


-- ----------------------------------------------------------------------------------------------------------------------------
-- DQ5  |  Outlier Detection — Financial Columns
-- Question   : Are numeric values in sensible ranges or are there extreme outliers?
-- Finding    : DTI max=999 (1,711 rows), income max=$9.93M (1,869 rows >$500K), revol_util max=191% (3,153 rows)
-- ----------------------------------------------------------------------------------------------------------------------------
SELECT
    MIN(loan_amnt)                              AS min_loan,
    MAX(loan_amnt)                              AS max_loan,
    ROUND(AVG(loan_amnt), 0)                   AS avg_loan,
    COUNT(CASE WHEN loan_amnt  <= 0     THEN 1 END) AS invalid_loan_amounts,
    MIN(annual_inc)                             AS min_income,
    MAX(annual_inc)                             AS max_income,
    COUNT(CASE WHEN annual_inc > 500000 THEN 1 END) AS income_over_500k,
    COUNT(CASE WHEN annual_inc <= 0     THEN 1 END) AS zero_or_negative_income,
    MIN(dti)                                    AS min_dti,
    MAX(dti)                                    AS max_dti,
    COUNT(CASE WHEN dti > 100           THEN 1 END) AS dti_over_100,
    COUNT(CASE WHEN dti < 0             THEN 1 END) AS negative_dti,
    MIN(revol_util)                             AS min_revol_util,
    MAX(revol_util)                             AS max_revol_util,
    COUNT(CASE WHEN revol_util > 100    THEN 1 END) AS revol_util_over_100,
    MIN(int_rate)                               AS min_rate,
    MAX(int_rate)                               AS max_rate,
    COUNT(CASE WHEN int_rate <= 0       THEN 1 END) AS invalid_rates
FROM loans;


-- ----------------------------------------------------------------------------------------------------------------------------
-- DQ6  |  Credit Grade Consistency Check
-- Question   : Are grade and risk_category values consistent with each other?
-- Finding    : All 7 grades A–G present, risk_category populated. B=29.77%, A=21.63%
-- ----------------------------------------------------------------------------------------------------------------------------
SELECT
    grade,
    risk_category,
    COUNT(*)                                    AS loan_count,
    CONCAT(ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER(), 2), '%')          AS portfolio_share
FROM loans
GROUP BY grade, risk_category
ORDER BY grade;


-- ----------------------------------------------------------------------------------------------------------------------------
-- DQ7  |  Employment Length Value Audit
-- Question   : Does emp_length contain only expected categories?
-- Finding    : 'n/a' string found (77,465 rows = 7.4%) — relabelled to 'Not Specified' in cleaning
-- ----------------------------------------------------------------------------------------------------------------------------
SELECT
    COALESCE(emp_length, 'NULL')                AS emp_length,
    COUNT(*)                                    AS borrower_count,
    CONCAT(ROUND(COUNT(*) * 100.0 /
        SUM(COUNT(*)) OVER(), 1), '%')          AS share
FROM loans
GROUP BY emp_length
ORDER BY borrower_count DESC;


-- ----------------------------------------------------------------------------------------------------------------------------
-- DQ8  |  Geographic Coverage Check
-- Question   : Are all US states present? Any states with suspiciously few loans?
-- Finding    : All 50 states present, zero NULLs, min=2,101 loans per state, max=141,149 (CA)
-- ----------------------------------------------------------------------------------------------------------------------------
SELECT
    COUNT(DISTINCT addr_state)                  AS distinct_states,
    SUM(CASE WHEN addr_state IS NULL
        THEN 1 ELSE 0 END)                      AS null_state_count,
    MIN(state_count)                            AS min_loans_per_state,
    MAX(state_count)                            AS max_loans_per_state
FROM (
    SELECT addr_state, COUNT(*) AS state_count
    FROM loans
    GROUP BY addr_state
) AS state_summary;


-- ----------------------------------------------------------------------------------------------------------------------------
-- DQ9  |  Data Quality Summary — One-Row Report Card
-- Question   : What is the overall data quality score?
-- Purpose    : Single summary row — copy findings into README.md
-- NOTE       : This single CTE scans loans table ONCE for all metrics
--              DQ1–DQ8 were separate for learning clarity
--              In production this single query replaces all of them
-- ----------------------------------------------------------------------------------------------------------------------------
WITH quality_metrics AS (
    SELECT
        COUNT(*)                                                    AS total_rows,
        COUNT(*) - COUNT(emp_length)                               AS null_emp_length,
        COUNT(*) - COUNT(dti)                                      AS null_dti,
        COUNT(*) - COUNT(revol_util)                               AS null_revol_util,
        COUNT(CASE WHEN loan_amnt  <= 0          THEN 1 END)      AS invalid_loan_amnt,
        COUNT(CASE WHEN annual_inc <= 0          THEN 1 END)      AS invalid_income,
        COUNT(CASE WHEN annual_inc > 500000      THEN 1 END)      AS outlier_income,
        COUNT(CASE WHEN dti > 100                THEN 1 END)      AS outlier_dti,
        COUNT(CASE WHEN dti < 0                  THEN 1 END)      AS negative_dti,
        COUNT(CASE WHEN revol_util > 100         THEN 1 END)      AS outlier_revol_util,
        COUNT(CASE WHEN home_ownership = 'ANY'   THEN 1 END)      AS ownership_any,
        COUNT(CASE WHEN purpose = 'wedding'      THEN 1 END)      AS wedding_purpose
    FROM loans
)
SELECT
    total_rows,
    null_emp_length,
    null_dti,
    null_revol_util,
    invalid_loan_amnt,
    invalid_income,
    outlier_income,
    outlier_dti,
    negative_dti,
    outlier_revol_util,
    ownership_any,
    wedding_purpose,
    CONCAT(ROUND(
        (total_rows - null_emp_length - invalid_income
        - outlier_dti - outlier_revol_util)
        * 100.0 / total_rows, 1), '%')          AS data_quality_score
FROM quality_metrics;


-- ============================================================================================================================
-- SECTION 0B : DATA CLEANING
-- Purpose    : Fix all 12 issues identified in Section 0A
--              Creates loans_clean VIEW — raw loans table stays untouched
--              All analysis in Sections A–E runs on loans_clean
--
--  CLEANING DECISIONS (based on actual data findings):
--    1.  TRIM(term)                    — leading space in every row
--    2.  COALESCE(emp_length)          — 77,465 NULLs → 'Not Specified'
--    3.  home_ownership 'ANY' → 'OTHER'— not a standard category (599 rows)
--    4.  annual_inc = 0    → NULL      — zero income loan is data error (1,174 rows)
--    5.  annual_inc > 500K → capped    — extreme outlier, max was $9.9M (1,869 rows)
--    6.  dti < 0           → NULL      — negative DTI impossible (1 row)
--    7.  dti > 100         → NULL      — data entry error, max was 999 (1,711 rows)
--    8.  revol_util > 100  → NULL      — impossible value, max was 191% (3,153 rows)
--    9.  purpose 'wedding' → 'other'   — only 7 rows, not meaningful
--    10. Raw loans table preserved     — annual_inc_raw kept for audit
-- ============================================================================================================================

DROP VIEW IF EXISTS loans_clean;

CREATE VIEW loans_clean AS
SELECT
    loan_amnt,
    TRIM(term)                                  AS term,
    int_rate, installment, grade, sub_grade,
    CASE
        WHEN emp_length IS NULL  THEN 'Not Specified'
        WHEN emp_length = 'n/a'  THEN 'Not Specified'
        ELSE emp_length
    END                                         AS emp_length,
    CASE WHEN home_ownership = 'ANY'
         THEN 'OTHER'
         ELSE home_ownership END                AS home_ownership,
    CASE WHEN annual_inc =  0      THEN NULL
         WHEN annual_inc > 500000  THEN 500000
         ELSE annual_inc END                    AS annual_inc,
    annual_inc                                  AS annual_inc_raw,
    verification_status, loan_status,
    CASE WHEN purpose = 'wedding'
         THEN 'other'
         ELSE purpose END                       AS purpose,
    addr_state,
    CASE WHEN dti IS NULL  THEN NULL
         WHEN dti < 0      THEN NULL
         WHEN dti > 100    THEN NULL
         ELSE dti END                           AS dti,
    CASE WHEN revol_util IS NULL  THEN NULL
         WHEN revol_util > 100    THEN NULL
         ELSE revol_util END                    AS revol_util,
    total_pymnt
FROM loans
WHERE loan_amnt    >  0
  AND loan_status  IS NOT NULL
  AND grade        IS NOT NULL;


-- POST-CLEANING VALIDATION — all problem counts should be 0

SELECT COUNT(*) FROM loans_clean;
SELECT
    'loans_clean'                               AS view_name,
    COUNT(*)                                    AS total_rows,
    COUNT(CASE WHEN term LIKE ' %'      THEN 1 END) AS term_spaces_remaining,
    COUNT(CASE WHEN emp_length IS NULL  THEN 1 END) AS emp_length_nulls_remaining,
    COUNT(CASE WHEN dti > 100           THEN 1 END) AS dti_outliers_remaining,
    COUNT(CASE WHEN revol_util > 100    THEN 1 END) AS revol_util_outliers_remaining,
    COUNT(CASE WHEN annual_inc = 0      THEN 1 END) AS zero_income_remaining,
    COUNT(CASE WHEN annual_inc > 500000 THEN 1 END) AS income_outliers_remaining,
    COUNT(CASE WHEN home_ownership='ANY'THEN 1 END) AS ownership_any_remaining,
    COUNT(CASE WHEN purpose = 'wedding' THEN 1 END) AS wedding_remaining
FROM loans_clean;


-- ============================================================================================================================
-- SECTION A : PORTFOLIO OVERVIEW
-- Business  : High-level snapshot of the entire loan book
--             Used in monthly MIS reports and senior management reviews
-- ============================================================================================================================

-- ----------------------------------------------------------------------------------------------------------------------------
-- A1  |  Executive Portfolio KPI Dashboard
-- Business  : Single-query summary for C-suite and senior management
-- Technique : Single-scan CTE — all 11 metrics in one table pass
-- Insight   : $16,132.19M portfolio · 12.80% avg rate · 10.15% overall risk rate · 94,286 charged off
-- ----------------------------------------------------------------------------------------------------------------------------
WITH portfolio_kpis AS (
    SELECT
        COUNT(*)                                                                     AS total_loans,
        SUM(loan_amnt)                                                               AS total_portfolio,
        AVG(loan_amnt)                                                               AS avg_loan,
        AVG(int_rate)                                                                AS avg_rate,
        AVG(dti)                                                                     AS avg_dti,
        SUM(total_pymnt)                                                             AS total_collected,
        COUNT(CASE WHEN loan_status = 'Fully Paid'                           THEN 1 END) AS fully_paid,
        COUNT(CASE WHEN loan_status = 'Current'                              THEN 1 END) AS current_loans,
        COUNT(CASE WHEN loan_status = 'Charged Off'                          THEN 1 END) AS charged_off,
        COUNT(CASE WHEN loan_status LIKE 'Late%'                             THEN 1 END) AS late_payments,
        COUNT(CASE WHEN loan_status IN ('Charged Off','Late (31-120 days)')  THEN 1 END) AS at_risk
    FROM loans_clean
)
SELECT
    total_loans,
    CONCAT('$ ', FORMAT(total_portfolio / 1000000, 2), 'M')                         AS total_portfolio_value,
    CONCAT('$ ', FORMAT(ROUND(avg_loan, 0), 0))                                     AS avg_loan_size,
    CONCAT(ROUND(avg_rate, 2), '%')                                                 AS avg_interest_rate,
    CONCAT(ROUND(avg_dti,  2), '%')                                                 AS avg_debt_to_income,
    CONCAT('$ ', FORMAT(total_collected / 1000000, 2), 'M')                        AS total_amount_collected,
    fully_paid,
    current_loans,
    charged_off,
    late_payments,
    CONCAT(ROUND(at_risk * 100.0 / total_loans, 2), '%')                           AS overall_risk_rate
FROM portfolio_kpis;


-- ----------------------------------------------------------------------------------------------------------------------------
-- A2  |  Portfolio Split by Loan Term
-- Business  : Compare 36-month vs 60-month loan product performance
-- Technique : CTE + SUM() OVER() for share — no scalar subquery
-- Insight   : 36-month = 71.4% (8.18% default) · 60-month = 28.6% (11.02% default) — longer tenure = higher risk
-- ----------------------------------------------------------------------------------------------------------------------------
WITH term_summary AS (
    SELECT
        term,
        COUNT(*)                                                                     AS total_loans,
        AVG(loan_amnt)                                                               AS avg_loan_amount,
        AVG(int_rate)                                                                AS avg_interest_rate,
        AVG(installment)                                                             AS avg_monthly_emi,
        COUNT(CASE WHEN loan_status = 'Charged Off'                          THEN 1 END) AS defaults
    FROM loans_clean
    GROUP BY term
)
SELECT
    term                                                                             AS loan_term,
    total_loans,
    CONCAT(ROUND(total_loans * 100.0 / SUM(total_loans) OVER(), 1), '%')           AS share_of_portfolio,
    CONCAT('$ ', FORMAT(ROUND(avg_loan_amount,  0), 0))                            AS avg_loan_amount,
    CONCAT(ROUND(avg_interest_rate, 2), '%')                                        AS avg_interest_rate,
    CONCAT('$ ', FORMAT(ROUND(avg_monthly_emi,  0), 0))                            AS avg_monthly_emi,
    defaults,
    CONCAT(ROUND(defaults * 100.0 / total_loans, 2), '%')                          AS default_rate
FROM term_summary
ORDER BY total_loans DESC;


-- ----------------------------------------------------------------------------------------------------------------------------
-- A3  |  Loan Purpose Analysis
-- Business  : Product-level volume, disbursement, and credit risk by borrower intent
-- Technique : CTE + SUM() OVER() for share; default_rate from named columns
-- Insight   : Debt consolidation = 55% volume · small_business = highest default (14.00%) · credit_card = lowest (6.99%)
-- ----------------------------------------------------------------------------------------------------------------------------
WITH purpose_summary AS (
    SELECT
        purpose,
        COUNT(*)                                                                     AS loan_count,
        SUM(loan_amnt)                                                               AS total_disbursed,
        AVG(int_rate)                                                                AS avg_rate,
        AVG(annual_inc)                                                              AS avg_borrower_income,
        COUNT(CASE WHEN loan_status = 'Charged Off'                          THEN 1 END) AS defaults
    FROM loans_clean
    GROUP BY purpose
)
SELECT
    purpose                                                                          AS loan_purpose,
    loan_count,
    CONCAT(ROUND(loan_count * 100.0 / SUM(loan_count) OVER(), 1), '%')             AS volume_share,
    CONCAT('$ ', FORMAT(total_disbursed, 0))                                        AS total_disbursed,
    CONCAT(ROUND(avg_rate, 2), '%')                                                 AS avg_rate,
    CONCAT('$ ', FORMAT(ROUND(avg_borrower_income, 0), 0))                         AS avg_borrower_income,
    defaults,
    CONCAT(ROUND(defaults * 100.0 / loan_count, 2), '%')                           AS default_rate
FROM purpose_summary
ORDER BY loan_count DESC;


-- ============================================================================================================================
-- SECTION B : DEFAULT & RISK ANALYSIS
-- Business  : Credit risk monitoring and NPA identification
-- ============================================================================================================================

-- ----------------------------------------------------------------------------------------------------------------------------
-- B1  |  Default Rate by Credit Grade
-- Business  : Grade-wise risk profiling — validates credit scoring model
-- Technique : CTE computes at_risk_accounts once; default_rate from named column
-- Insight   : Grade G = 40.76% default · Grade A = 2.22% · G defaults 17x more than A — model validated
-- ----------------------------------------------------------------------------------------------------------------------------
WITH grade_summary AS (
    SELECT
        grade,
        risk_category,
        COUNT(*)                                                                     AS total_loans,
        COUNT(CASE WHEN loan_status IN
            ('Charged Off', 'Late (31-120 days)', 'Default')                THEN 1 END) AS at_risk_accounts,
        AVG(int_rate)                                                                AS avg_rate,
        AVG(dti)                                                                     AS avg_dti,
        AVG(annual_inc)                                                              AS avg_annual_income,
        AVG(loan_amnt)                                                               AS avg_loan_amount
    FROM loans_clean
    GROUP BY grade, risk_category
)
SELECT
    grade,
    risk_category,
    total_loans,
    at_risk_accounts,
    CONCAT(ROUND(at_risk_accounts * 100.0 / total_loans, 2), '%')                  AS default_rate,
    CONCAT(ROUND(avg_rate, 2), '%')                                                 AS avg_interest_rate,
    ROUND(avg_dti, 2)                                                               AS avg_dti,
    CONCAT('$ ', FORMAT(ROUND(avg_annual_income, 0), 0))                           AS avg_annual_income,
    CONCAT('$ ', FORMAT(ROUND(avg_loan_amount,   0), 0))                           AS avg_loan_amount
FROM grade_summary
ORDER BY grade;


-- ----------------------------------------------------------------------------------------------------------------------------
-- B2  |  Risk Profile by Home Ownership
-- Business  : Does property ownership correlate with lower default probability?
-- Technique : CTE computes defaults once; default_rate from named columns
-- Insight   : MORTGAGE = lowest default (7.62%) · RENT = highest (10.64%) · 40% more risk than MORTGAGE
-- ----------------------------------------------------------------------------------------------------------------------------
WITH ownership_summary AS (
    SELECT
        home_ownership,
        COUNT(*)                                                                     AS total_borrowers,
        AVG(annual_inc)                                                              AS avg_income,
        AVG(loan_amnt)                                                               AS avg_loan,
        AVG(dti)                                                                     AS avg_dti,
        COUNT(CASE WHEN loan_status = 'Charged Off'                          THEN 1 END) AS defaults
    FROM loans_clean
    GROUP BY home_ownership
)
SELECT
    home_ownership,
    total_borrowers,
    CONCAT('$ ', FORMAT(ROUND(avg_income, 0), 0))                                  AS avg_income,
    CONCAT('$ ', FORMAT(ROUND(avg_loan,   0), 0))                                  AS avg_loan,
    ROUND(avg_dti, 2)                                                               AS avg_dti,
    defaults,
    CONCAT(ROUND(defaults * 100.0 / total_borrowers, 2), '%')                      AS default_rate
FROM ownership_summary
ORDER BY total_borrowers DESC;


-- ----------------------------------------------------------------------------------------------------------------------------
-- B3  |  DTI Bucket Analysis
-- Business  : How debt burden impacts repayment — key underwriting variable
-- Technique : CTE buckets continuous DTI into 4 bands; default_rate from named columns
-- Insight   : Very High DTI (>30%) = 11.77% default · Low DTI (<10%) = 6.55% · 1.8x higher risk
-- ----------------------------------------------------------------------------------------------------------------------------
WITH dti_buckets AS (
    SELECT
        CASE
            WHEN dti <  10 THEN '1. Low DTI       (Below 10%)'
            WHEN dti <  20 THEN '2. Medium DTI    (10% - 20%)'
            WHEN dti <  30 THEN '3. High DTI      (20% - 30%)'
            ELSE                '4. Very High DTI (Above 30%)'
        END                                                                         AS dti_bucket,
        COUNT(*)                                                                     AS borrowers,
        AVG(loan_amnt)                                                               AS avg_loan,
        AVG(int_rate)                                                                AS avg_rate,
        AVG(annual_inc)                                                              AS avg_income,
        COUNT(CASE WHEN loan_status = 'Charged Off'                          THEN 1 END) AS defaults
    FROM loans_clean
    GROUP BY dti_bucket
)
SELECT
    dti_bucket,
    borrowers,
    CONCAT('$ ', FORMAT(ROUND(avg_loan,   0), 0))                                  AS avg_loan,
    CONCAT(ROUND(avg_rate, 2), '%')                                                 AS avg_rate,
    CONCAT('$ ', FORMAT(ROUND(avg_income, 0), 0))                                  AS avg_income,
    defaults,
    CONCAT(ROUND(defaults * 100.0 / borrowers, 2), '%')                            AS default_rate
FROM dti_buckets
ORDER BY dti_bucket;


-- ============================================================================================================================
-- SECTION C : INCOME & AFFORDABILITY ANALYSIS
-- ============================================================================================================================

-- ----------------------------------------------------------------------------------------------------------------------------
-- C1  |  Income Band Segmentation
-- Business  : Which income bands carry highest credit risk?
-- Technique : CTE buckets annual_inc; SUM(borrowers) OVER() for share
-- Insight   : $40K-$70K = largest band (36.9%) · Below $40K = highest default (10.58%) · Above $150K = safest (5.98%)
-- ----------------------------------------------------------------------------------------------------------------------------
WITH income_bands AS (
    SELECT
        CASE
            WHEN annual_inc <  40000  THEN '1. Below $40K'
            WHEN annual_inc <  70000  THEN '2. $40K  - $70K'
            WHEN annual_inc <  100000 THEN '3. $70K  - $100K'
            WHEN annual_inc <  150000 THEN '4. $100K - $150K'
            ELSE                           '5. Above $150K'
        END                                                                         AS income_band,
        COUNT(*)                                                                     AS borrowers,
        AVG(loan_amnt)                                                               AS avg_loan,
        AVG(int_rate)                                                                AS avg_rate,
        AVG(dti)                                                                     AS avg_dti,
        COUNT(CASE WHEN loan_status = 'Charged Off'                          THEN 1 END) AS defaults
    FROM loans_clean
    GROUP BY income_band
)
SELECT
    income_band,
    borrowers,
    CONCAT(ROUND(borrowers * 100.0 / SUM(borrowers) OVER(), 1), '%')               AS share_of_portfolio,
    CONCAT('$ ', FORMAT(ROUND(avg_loan, 0), 0))                                    AS avg_loan,
    CONCAT(ROUND(avg_rate, 2), '%')                                                 AS avg_rate,
    ROUND(avg_dti, 2)                                                               AS avg_dti,
    defaults,
    CONCAT(ROUND(defaults * 100.0 / borrowers, 2), '%')                            AS default_rate
FROM income_bands
ORDER BY income_band;


-- ----------------------------------------------------------------------------------------------------------------------------
-- C2  |  Employment Length vs Loan Default
-- Business  : Is job stability a reliable credit risk predictor?
-- Technique : emp_length pre-categorised — grouped directly; all metrics one CTE pass
-- Insight   : Not Specified = highest default (10.84%) · 10+ years = most stable (8.36%) · employment is weak predictor
-- ----------------------------------------------------------------------------------------------------------------------------
WITH employment_summary AS (
    SELECT
        emp_length,
        COUNT(*)                                                                     AS total_borrowers,
        AVG(loan_amnt)                                                               AS avg_loan,
        AVG(annual_inc)                                                              AS avg_income,
        AVG(revol_util)                                                              AS avg_revol_util,
        COUNT(CASE WHEN loan_status = 'Charged Off'                          THEN 1 END) AS defaults
    FROM loans_clean
    GROUP BY emp_length
)
SELECT
    emp_length                                                                       AS employment_length,
    total_borrowers,
    CONCAT('$ ', FORMAT(ROUND(avg_loan,   0), 0))                                  AS avg_loan,
    CONCAT('$ ', FORMAT(ROUND(avg_income, 0), 0))                                  AS avg_income,
    defaults,
    CONCAT(ROUND(defaults * 100.0 / total_borrowers, 2), '%')                      AS default_rate,
    CONCAT(ROUND(avg_revol_util, 1), '%')                                           AS avg_credit_utilization
FROM employment_summary
ORDER BY default_rate DESC;


-- ============================================================================================================================
-- SECTION D : ADVANCED ANALYTICS — CTEs & WINDOW FUNCTIONS
-- ============================================================================================================================

-- ----------------------------------------------------------------------------------------------------------------------------
-- D1  |  Grade-wise Risk Ranking  |  CTE + RANK() OVER()
-- Business  : Rank all credit grades by default rate for risk review
-- Technique : CTE pre-computes defaults once; RANK() uses named columns
-- Insight   : Grade G = Rank 1 (38.68% default) · Grade A = Rank 7 (2.22%) · 17x difference confirms model validity
-- ----------------------------------------------------------------------------------------------------------------------------
WITH grade_defaults AS (
    SELECT
        grade,
        risk_category,
        COUNT(*)                                                                     AS total_loans,
        COUNT(CASE WHEN loan_status = 'Charged Off'                          THEN 1 END) AS defaults,
        AVG(int_rate)                                                                AS avg_rate
    FROM loans_clean
    GROUP BY grade, risk_category
)
SELECT
    grade,
    risk_category,
    total_loans,
    defaults,
    ROUND(defaults * 100.0 / total_loans, 2)                                       AS default_rate_pct,
    CONCAT(ROUND(avg_rate, 2), '%')                                                 AS avg_rate,
    RANK() OVER (ORDER BY defaults * 1.0 / total_loans DESC)                       AS risk_rank
FROM grade_defaults
ORDER BY risk_rank;


-- ----------------------------------------------------------------------------------------------------------------------------
-- D2  |  State-wise Cumulative Portfolio  |  CTE + SUM() OVER (ROWS BETWEEN)
-- Business  : Running total of disbursement by state — geographic concentration risk
-- Technique : CTE does GROUP BY once; window uses plain column — no SUM(SUM()) nesting
-- Insight   : CA = 13.88% ($2.24B) · Top 5 states = 41.8% · Top 10 states = 58.3% — geographic concentration risk
-- ----------------------------------------------------------------------------------------------------------------------------
WITH state_totals AS (
    SELECT
        addr_state                                                                   AS state,
        COUNT(*)                                                                     AS loan_count,
        SUM(loan_amnt)                                                               AS state_amount
    FROM loans_clean
    GROUP BY addr_state
)
SELECT
    state,
    loan_count,
    CONCAT('$ ', FORMAT(state_amount, 0))                                           AS state_total,
    CONCAT('$ ', FORMAT(
        SUM(state_amount) OVER (
            ORDER BY state_amount DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ), 0))                                                                       AS cumulative_total,
    CONCAT(ROUND(state_amount * 100.0 / SUM(state_amount) OVER(), 2), '%')         AS pct_of_portfolio
FROM state_totals
ORDER BY state_amount DESC
LIMIT 15;


-- ----------------------------------------------------------------------------------------------------------------------------
-- D3  |  Multi-Factor Borrower Risk Scoring  |  Three-Level CTE
-- Business  : Classify borrowers as PRIME / NEAR PRIME / SUBPRIME
-- Technique : Level 1 scores 4 factors · Level 2 segments · Level 3 aggregates
-- Insight   : SUBPRIME = 16.42% default · PRIME = 4.46% · SUBPRIME defaults 3.7x more · NEAR PRIME = largest (53.9%)
-- ----------------------------------------------------------------------------------------------------------------------------
WITH risk_factors AS (
    SELECT
        grade, annual_inc, dti, revol_util, loan_amnt, loan_status,
        CASE WHEN grade IN ('A','B') THEN 3 WHEN grade = 'C' THEN 2 ELSE 1 END     AS grade_score,
        CASE WHEN dti        <  15   THEN 3 WHEN dti        < 25  THEN 2 ELSE 1 END AS dti_score,
        CASE WHEN revol_util <  30   THEN 3 WHEN revol_util < 60  THEN 2 ELSE 1 END AS util_score,
        CASE WHEN annual_inc > 80000 THEN 3 WHEN annual_inc > 50000 THEN 2 ELSE 1 END AS income_score
    FROM loans_clean
),
borrower_segs AS (
    SELECT *,
        (grade_score + dti_score + util_score + income_score)                       AS total_score,
        CASE
            WHEN (grade_score + dti_score + util_score + income_score) >= 10 THEN 'PRIME'
            WHEN (grade_score + dti_score + util_score + income_score) >= 7  THEN 'NEAR PRIME'
            ELSE 'SUBPRIME'
        END                                                                         AS borrower_segment
    FROM risk_factors
),
segment_summary AS (
    SELECT
        borrower_segment,
        COUNT(*)                                                                     AS total_borrowers,
        AVG(loan_amnt)                                                               AS avg_loan,
        AVG(annual_inc)                                                              AS avg_income,
        AVG(dti)                                                                     AS avg_dti,
        AVG(revol_util)                                                              AS avg_revol_util,
        COUNT(CASE WHEN loan_status = 'Charged Off'                          THEN 1 END) AS defaults
    FROM borrower_segs
    GROUP BY borrower_segment
)
SELECT
    borrower_segment,
    total_borrowers,
    CONCAT(ROUND(total_borrowers * 100.0 / SUM(total_borrowers) OVER(), 1), '%')   AS portfolio_share,
    CONCAT('$ ', FORMAT(ROUND(avg_loan,     0), 0))                                AS avg_loan,
    CONCAT('$ ', FORMAT(ROUND(avg_income,   0), 0))                                AS avg_income,
    ROUND(avg_dti, 2)                                                               AS avg_dti,
    CONCAT(ROUND(avg_revol_util, 1), '%')                                           AS avg_credit_util,
    defaults,
    CONCAT(ROUND(defaults * 100.0 / total_borrowers, 2), '%')                      AS default_rate
FROM segment_summary
ORDER BY default_rate DESC;


-- ----------------------------------------------------------------------------------------------------------------------------
-- D4  |  Top Default States  |  CTE + DENSE_RANK()
-- Business  : Geographic risk concentration — regional credit policy decisions
-- Technique : CTE one scan; HAVING filters low-volume states; DENSE_RANK on named column
-- Insight   : Arkansas = rank 1 (10.98%) · Top 5 all Southern/Midwestern states · NY rank 10 (9.75%) despite large volume
-- ----------------------------------------------------------------------------------------------------------------------------
WITH state_risk AS (
    SELECT
        addr_state                                                                   AS state,
        COUNT(*)                                                                     AS total_loans,
        COUNT(CASE WHEN loan_status = 'Charged Off'                          THEN 1 END) AS defaults,
        ROUND(AVG(loan_amnt), 0)                                                    AS avg_loan,
        ROUND(AVG(int_rate),  2)                                                    AS avg_rate,
        ROUND(AVG(dti),       2)                                                    AS avg_dti
    FROM loans_clean
    GROUP BY addr_state
    HAVING COUNT(*) >= 50
)
SELECT
    state,
    total_loans,
    defaults,
    CONCAT(ROUND(defaults * 100.0 / total_loans, 2), '%')                          AS default_rate,
    CONCAT('$ ', FORMAT(avg_loan, 0))                                              AS avg_loan,
    CONCAT(avg_rate, '%')                                                           AS avg_rate,
    avg_dti,
    DENSE_RANK() OVER (ORDER BY defaults * 1.0 / total_loans DESC)                 AS risk_rank
FROM state_risk
ORDER BY risk_rank
LIMIT 10;


-- ----------------------------------------------------------------------------------------------------------------------------
-- D5  |  Grade-over-Grade Rate Comparison  |  CTE + LAG()
-- Business  : Incremental rate premium and default jump at each grade step
-- Technique : CTE aggregates per grade once; LAG() on named columns
-- Insight   : Largest default jump E→F (+11.09%) · D→E also significant (+7.44%) · Grade F under-priced relative to risk
-- ----------------------------------------------------------------------------------------------------------------------------
WITH grade_rates AS (
    SELECT
        grade,
        ROUND(AVG(int_rate), 2)                                                     AS avg_rate,
        COUNT(*)                                                                     AS loans,
        ROUND(AVG(dti), 2)                                                          AS avg_dti,
        ROUND(COUNT(CASE WHEN loan_status = 'Charged Off'
            THEN 1 END) * 100.0 / COUNT(*), 2)                                     AS default_pct
    FROM loans_clean
    GROUP BY grade
)
SELECT
    grade,
    avg_rate,
    loans,
    default_pct,
    avg_dti,
    LAG(avg_rate)    OVER (ORDER BY grade)                                          AS prev_grade_rate,
    ROUND(avg_rate    - LAG(avg_rate)    OVER (ORDER BY grade), 2)                  AS rate_jump,
    LAG(default_pct) OVER (ORDER BY grade)                                         AS prev_grade_default,
    ROUND(default_pct - LAG(default_pct) OVER (ORDER BY grade), 2)                 AS default_jump
FROM grade_rates
ORDER BY grade;


-- ----------------------------------------------------------------------------------------------------------------------------
-- D6  |  Loan Amount Quartile Distribution  |  Manual Quartile Bucketing
-- Business  : Portfolio concentration by loan size — large-ticket tail risk
-- Technique : CASE WHEN manual boundaries replace NTILE(4) — more performant
--             on large datasets (1M+ rows). Boundaries: $8K / $15K / $24K
-- Insight   : Q2 Medium ($8K-$15K) = largest (341,535 loans) · Q4 avg=$31,317 = highest tail risk · Q1+Q2 = 59% of loans
-- ----------------------------------------------------------------------------------------------------------------------------
SELECT
    quartile_label,
    COUNT(*)                                    AS loan_count,
    MIN(loan_amnt)                              AS min_loan,
    MAX(loan_amnt)                              AS max_loan,
    ROUND(AVG(loan_amnt), 0)                   AS avg_loan
FROM (
    SELECT
        loan_amnt,
        CASE
            WHEN loan_amnt <= 8000  THEN 'Q1 - Small Loans'
            WHEN loan_amnt <= 15000 THEN 'Q2 - Medium Loans'
            WHEN loan_amnt <= 24000 THEN 'Q3 - Large Loans'
            ELSE                         'Q4 - Very Large Loans'
        END AS quartile_label
    FROM loans_clean
) AS buckets
GROUP BY quartile_label
ORDER BY MIN(loan_amnt);


-- ============================================================================================================================
-- SECTION E : EXECUTIVE BUSINESS SUMMARY REPORT
-- ============================================================================================================================

-- ----------------------------------------------------------------------------------------------------------------------------
-- E1  |  Complete Portfolio Health Report  |  CTE + UNION ALL
-- Business  : One-page management report — export to Excel/PDF for board meetings
-- Technique : CTE scans loans_clean ONCE; all UNION ALL rows read from memory
-- ----------------------------------------------------------------------------------------------------------------------------
WITH portfolio_stats AS (
    SELECT
        COUNT(*)                                                                     AS total_loans,
        SUM(loan_amnt)                                                               AS total_portfolio,
        SUM(total_pymnt)                                                             AS total_collected,
        AVG(loan_amnt)                                                               AS avg_loan,
        AVG(int_rate)                                                                AS avg_rate,
        AVG(dti)                                                                     AS avg_dti,
        COUNT(CASE WHEN loan_status = 'Current'                              THEN 1 END) AS current_loans,
        COUNT(CASE WHEN loan_status = 'Fully Paid'                           THEN 1 END) AS fully_paid,
        COUNT(CASE WHEN loan_status = 'Charged Off'                          THEN 1 END) AS charged_off,
        COUNT(CASE WHEN loan_status LIKE 'Late%'                             THEN 1 END) AS late_payments
    FROM loans_clean
)
SELECT '--- PORTFOLIO SUMMARY ---'               AS report_section, '' AS metric, '' AS value
UNION ALL SELECT '', 'Total Loans',              CONCAT(FORMAT(total_loans, 0), ' loans')                FROM portfolio_stats
UNION ALL SELECT '', 'Total Portfolio Value',    CONCAT('$ ', FORMAT(total_portfolio / 1000000, 2), 'M') FROM portfolio_stats
UNION ALL SELECT '', 'Total Amount Collected',   CONCAT('$ ', FORMAT(total_collected / 1000000, 2), 'M') FROM portfolio_stats
UNION ALL SELECT '', 'Avg Loan Size',            CONCAT('$ ', FORMAT(ROUND(avg_loan, 0), 0))             FROM portfolio_stats
UNION ALL SELECT '', 'Avg Interest Rate',        CONCAT(ROUND(avg_rate, 2), '%')                         FROM portfolio_stats
UNION ALL SELECT '', 'Avg Debt-to-Income Ratio', CONCAT(ROUND(avg_dti,  2), '%')                         FROM portfolio_stats
UNION ALL SELECT '--- LOAN STATUS BREAKDOWN ---', '', ''
UNION ALL SELECT '', 'Current (Active Loans)',   FORMAT(current_loans, 0)                                FROM portfolio_stats
UNION ALL SELECT '', 'Fully Paid',               FORMAT(fully_paid,    0)                                FROM portfolio_stats
UNION ALL SELECT '', 'Charged Off (Defaulted)',  FORMAT(charged_off,   0)                                FROM portfolio_stats
UNION ALL SELECT '', 'Late Payments',            FORMAT(late_payments, 0)                                FROM portfolio_stats;


-- ============================================================================================================================
-- END OF PROJECT
-- Author   : Rupali Patra
-- Contact  : rupalipatra1994@gmail.com
-- GitHub   : github.com/RupaliPatra/loan-portfolio-analysis
-- ============================================================================================================================
