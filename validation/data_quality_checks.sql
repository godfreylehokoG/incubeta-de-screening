-- =============================================================================
-- VALIDATION: Data Quality Assertions on Silver Layer
-- =============================================================================
-- File:    data_quality_checks.sql
-- Purpose: Assert that the Silver layer meets all expected data quality
--          contracts. Every row in this output should show pass = TRUE.
--
-- APPROACH:
--   Each assertion is a named check that returns TRUE if the data meets
--   the expected condition. This is the same pattern used by dbt tests
--   and Great Expectations — simple, auditable, and easy to automate.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Run all quality assertions in a single query
-- -----------------------------------------------------------------------------
SELECT
  'no_null_transaction_id'    AS check_name,
  COUNTIF(transaction_id IS NULL) = 0 AS passed,
  COUNTIF(transaction_id IS NULL)     AS violations
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'no_null_customer_id',
  COUNTIF(customer_id IS NULL) = 0,
  COUNTIF(customer_id IS NULL)
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'no_null_signup_date',
  COUNTIF(signup_date IS NULL) = 0,
  COUNTIF(signup_date IS NULL)
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'no_null_purchase_date',
  COUNTIF(purchase_date IS NULL) = 0,
  COUNTIF(purchase_date IS NULL)
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'all_amounts_positive',
  COUNTIF(amount <= 0) = 0,
  COUNTIF(amount <= 0)
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'no_null_is_returned',
  COUNTIF(is_returned IS NULL) = 0,
  COUNTIF(is_returned IS NULL)
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'days_to_first_purchase_non_negative',
  COUNTIF(days_to_first_purchase < 0) = 0,
  COUNTIF(days_to_first_purchase < 0)
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'no_duplicate_transaction_ids',
  COUNT(*) - COUNT(DISTINCT transaction_id) = 0,
  COUNT(*) - COUNT(DISTINCT transaction_id)
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'valid_item_categories',
  COUNTIF(item_category NOT IN ('Electronics', 'Beauty', 'Sports', 'Home', 'Apparel', 'Automotive')) = 0,
  COUNTIF(item_category NOT IN ('Electronics', 'Beauty', 'Sports', 'Home', 'Apparel', 'Automotive'))
FROM retail_silver.cleaned_transactions

UNION ALL

-- Gold layer assertion: every Silver row got a segment
SELECT
  'gold_all_rows_have_segment',
  COUNTIF(customer_segment IS NULL) = 0,
  COUNTIF(customer_segment IS NULL)
FROM retail_gold.analytics_customer_segments;

-- Expected: ALL checks should show passed = TRUE, violations = 0
