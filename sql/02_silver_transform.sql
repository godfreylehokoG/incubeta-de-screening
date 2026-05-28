-- =============================================================================
-- SILVER LAYER: Data Cleansing & Transformation
-- =============================================================================
-- File:    02_silver_transform.sql
-- Layer:   Silver (Cleansed / Conformed)
-- Purpose: Transform raw Bronze data into a clean, typed, validated dataset
--          ready for analytics and ML consumption.
--
-- APPROACH:
--   This script uses a CTE (Common Table Expression) pipeline — each CTE is a
--   discrete, testable transformation step. This makes the logic easy to debug,
--   audit, and walk through in a code review or interview setting.
--
--   The pipeline flows: source → cast → impute → filter → enrich → output
--
-- DATA QUALITY ISSUES ADDRESSED:
--   1. String "NULL" literals in signup_date and is_returned (not SQL NULLs)
--   2. Missing signup_date → coalesced to purchase_date
--   3. Missing is_returned → defaulted to FALSE
--   4. Negative / zero amounts → filtered out (invalid for purchases)
--   5. All dates cast to DATE type, amounts to NUMERIC
--   6. New feature: days_to_first_purchase
--
-- BIGQUERY OPTIMISATIONS:
--   - Partitioned by purchase_date for time-range query performance & cost control
--   - Clustered by item_category for fast filtered scans (ML training, reporting)
--   - SAFE_CAST used throughout to prevent pipeline failures on unexpected data
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Step 1: Create the Silver dataset
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS retail_silver
OPTIONS (
  description = 'Silver layer: cleansed, typed, and validated data',
  labels = [('layer', 'silver'), ('domain', 'retail')]
);

-- -----------------------------------------------------------------------------
-- Step 2: Build the cleaned_transactions table via CTE pipeline
-- -----------------------------------------------------------------------------
CREATE OR REPLACE TABLE retail_silver.cleaned_transactions
PARTITION BY purchase_date
CLUSTER BY item_category
OPTIONS (
  description = 'Cleansed retail transactions — typed, imputed, filtered, and enriched',
  labels = [('layer', 'silver'), ('source', 'bronze')]
)
AS

-- ─── CTE 1: SOURCE ─────────────────────────────────────────────────────────
-- Read raw data from Bronze. No transformations yet — just establishing
-- the starting point of our pipeline.
WITH source AS (
  SELECT
    transaction_id,
    customer_id,
    signup_date     AS raw_signup_date,
    purchase_date   AS raw_purchase_date,
    amount          AS raw_amount,
    item_category,
    is_returned     AS raw_is_returned
  FROM retail_bronze.raw_transactions
),

-- ─── CTE 2: CAST & CLEAN ───────────────────────────────────────────────────
-- Handle the two forms of "null" in this dataset:
--   1. Actual SQL NULLs (if the CSV field was empty)
--   2. The literal string "NULL" (which the source system writes explicitly)
--
-- NULLIF(value, 'NULL') converts string "NULL" → SQL NULL, then SAFE_CAST
-- handles type conversion without throwing errors on malformed values.
--
-- DESIGN DECISION: Using SAFE_CAST instead of CAST because if a future data
-- load contains a malformed date like "2025-13-45", we want the row to get
-- a NULL date (which downstream logic can handle) rather than crashing the
-- entire pipeline.
cast_and_clean AS (
  SELECT
    transaction_id,
    customer_id,
    SAFE_CAST(NULLIF(TRIM(raw_signup_date), 'NULL')   AS DATE)      AS signup_date,
    SAFE_CAST(TRIM(raw_purchase_date)                  AS DATE)      AS purchase_date,
    SAFE_CAST(TRIM(raw_amount)                         AS NUMERIC)   AS amount,
    TRIM(item_category)                                              AS item_category,
    -- Normalise: string "NULL" → SQL NULL, then TRUE/FALSE → BOOL
    SAFE_CAST(NULLIF(TRIM(raw_is_returned), 'NULL')    AS BOOL)      AS is_returned
  FROM source
),

-- ─── CTE 3: IMPUTE MISSING VALUES ──────────────────────────────────────────
-- Business rules for handling missing data:
--   - signup_date: If unknown, assume the customer signed up on their first
--     purchase date. This is a conservative estimate that avoids excluding
--     records while keeping days_to_first_purchase meaningful (it becomes 0).
--   - is_returned: If unknown, default to FALSE. A missing return flag most
--     likely means no return was initiated. This is safer than excluding the
--     record, which would bias our ML model toward returned items.
imputed AS (
  SELECT
    transaction_id,
    customer_id,
    COALESCE(signup_date, purchase_date)  AS signup_date,
    purchase_date,
    amount,
    item_category,
    IFNULL(is_returned, FALSE)            AS is_returned
  FROM cast_and_clean
),

-- ─── CTE 4: FILTER INVALID RECORDS ─────────────────────────────────────────
-- Remove transactions where amount <= 0. These represent:
--   - Negative amounts: likely refunds, chargebacks, or data entry errors
--   - Zero amounts: free samples, test transactions, or placeholder records
--
-- WHY THIS MATTERS FOR ML:
--   K-means clustering on amount is distance-based. Negative/zero values
--   would create an artificial cluster of "non-purchases" that doesn't
--   represent real customer spending behaviour. Filtering them here keeps
--   the Silver layer clean for all downstream consumers, not just our model.
--
-- NOTE: In a production system, we might route these to a separate
-- retail_silver.filtered_transactions table for audit purposes rather
-- than discarding them entirely.
filtered AS (
  SELECT *
  FROM imputed
  WHERE amount > 0
    AND purchase_date IS NOT NULL  -- Safety net: exclude rows where date casting failed
),

-- ─── CTE 5: ENRICH WITH FEATURES ───────────────────────────────────────────
-- Add calculated columns that provide analytical value:
--   - days_to_first_purchase: Time between signup and first purchase.
--     This is a key engagement metric — short gaps suggest high intent,
--     long gaps may indicate a customer needed more nurturing.
--   - _processed_at: Pipeline audit timestamp for data freshness tracking.
enriched AS (
  SELECT
    transaction_id,
    customer_id,
    signup_date,
    purchase_date,
    amount,
    item_category,
    is_returned,
    DATE_DIFF(purchase_date, signup_date, DAY)  AS days_to_first_purchase,
    CURRENT_TIMESTAMP()                         AS _processed_at
  FROM filtered
)

-- ─── FINAL OUTPUT ───────────────────────────────────────────────────────────
SELECT * FROM enriched;

-- =============================================================================
-- POST-TRANSFORM SANITY CHECK
-- =============================================================================
-- Run this after the CREATE TABLE to verify the transformation results.
-- Expected: ~9,593 rows (10,000 minus ~407 non-positive amounts)

-- SELECT
--   COUNT(*)                                  AS total_rows,
--   COUNTIF(signup_date IS NULL)              AS null_signup_dates,    -- expect 0
--   COUNTIF(is_returned IS NULL)              AS null_is_returned,     -- expect 0
--   COUNTIF(amount <= 0)                      AS invalid_amounts,      -- expect 0
--   MIN(days_to_first_purchase)               AS min_days,
--   MAX(days_to_first_purchase)               AS max_days,
--   ROUND(AVG(days_to_first_purchase), 1)     AS avg_days,
--   COUNT(DISTINCT item_category)             AS distinct_categories   -- expect 6
-- FROM retail_silver.cleaned_transactions;
