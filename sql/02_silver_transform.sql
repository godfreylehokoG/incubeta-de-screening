-- =============================================================================
-- SILVER LAYER: Data Cleansing and Transformation
-- =============================================================================
-- Purpose: transform raw Bronze rows into typed, validated transactions for
-- analytics and BQML.
--
-- Key rules:
-- - Cast dates and amount to analytic types.
-- - Convert literal "NULL" values to SQL NULL before casting.
-- - Default missing signup_date to purchase_date.
-- - Default missing is_returned to FALSE.
-- - Exclude transactions with amount <= 0.
-- - Add days_to_first_purchase.
-- =============================================================================

-- Silver dataset.
CREATE SCHEMA IF NOT EXISTS retail_silver
OPTIONS (
  description = 'Silver layer: cleansed, typed, and validated data',
  labels = [('layer', 'silver'), ('domain', 'retail')]
);

-- Retention note:
-- Dataset/table expiration defaults should be disabled so historical
-- purchase_date partitions are retained.

-- Cleaned Silver table.
DROP TABLE IF EXISTS retail_silver.cleaned_transactions;

CREATE TABLE retail_silver.cleaned_transactions
PARTITION BY purchase_date
CLUSTER BY item_category
OPTIONS (
  description = 'Cleansed retail transactions: typed, imputed, filtered, and enriched',
  labels = [('layer', 'silver'), ('source', 'bronze')]
)
AS
WITH source AS (
  SELECT
    transaction_id,
    customer_id,
    signup_date   AS raw_signup_date,
    purchase_date AS raw_purchase_date,
    amount        AS raw_amount,
    item_category,
    is_returned   AS raw_is_returned
  FROM retail_bronze.raw_transactions
),

cast_and_clean AS (
  SELECT
    transaction_id,
    customer_id,
    SAFE_CAST(NULLIF(TRIM(raw_signup_date), 'NULL') AS DATE) AS signup_date,
    SAFE_CAST(TRIM(raw_purchase_date) AS DATE)                AS purchase_date,
    SAFE_CAST(TRIM(raw_amount) AS NUMERIC)                    AS amount,
    TRIM(item_category)                                       AS item_category,
    SAFE_CAST(NULLIF(TRIM(raw_is_returned), 'NULL') AS BOOL)  AS is_returned
  FROM source
),

imputed AS (
  SELECT
    transaction_id,
    customer_id,
    COALESCE(signup_date, purchase_date) AS signup_date,
    purchase_date,
    amount,
    item_category,
    IFNULL(is_returned, FALSE)           AS is_returned
  FROM cast_and_clean
),

filtered AS (
  SELECT *
  FROM imputed
  WHERE amount > 0
    AND purchase_date IS NOT NULL
)

SELECT
  transaction_id,
  customer_id,
  signup_date,
  purchase_date,
  amount,
  item_category,
  is_returned,
  DATE_DIFF(purchase_date, signup_date, DAY) AS days_to_first_purchase,
  CURRENT_TIMESTAMP()                        AS _processed_at
FROM filtered;

-- Expected sanity check:
-- SELECT
--   COUNT(*)                              AS total_rows,
--   COUNTIF(signup_date IS NULL)          AS null_signup_dates,
--   COUNTIF(is_returned IS NULL)          AS null_is_returned,
--   COUNTIF(amount <= 0)                  AS invalid_amounts,
--   COUNT(DISTINCT item_category)         AS distinct_categories
-- FROM retail_silver.cleaned_transactions;
