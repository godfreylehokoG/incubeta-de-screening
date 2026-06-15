-- =============================================================================
-- VALIDATION: Data Quality Assertions
-- =============================================================================
-- Purpose: assert that Silver and Gold tables meet expected quality contracts.
-- Every row in this output should show passed = TRUE and violations = 0.
-- =============================================================================

SELECT
  'silver_no_null_transaction_id' AS check_name,
  COUNTIF(transaction_id IS NULL) = 0 AS passed,
  COUNTIF(transaction_id IS NULL) AS violations
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'silver_no_null_customer_id',
  COUNTIF(customer_id IS NULL) = 0,
  COUNTIF(customer_id IS NULL)
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'silver_no_null_signup_date',
  COUNTIF(signup_date IS NULL) = 0,
  COUNTIF(signup_date IS NULL)
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'silver_no_null_purchase_date',
  COUNTIF(purchase_date IS NULL) = 0,
  COUNTIF(purchase_date IS NULL)
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'silver_all_amounts_positive',
  COUNTIF(amount <= 0) = 0,
  COUNTIF(amount <= 0)
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'silver_no_null_is_returned',
  COUNTIF(is_returned IS NULL) = 0,
  COUNTIF(is_returned IS NULL)
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'silver_days_to_first_purchase_non_negative',
  COUNTIF(days_to_first_purchase < 0) = 0,
  COUNTIF(days_to_first_purchase < 0)
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'silver_no_duplicate_transaction_ids',
  COUNT(*) - COUNT(DISTINCT transaction_id) = 0,
  COUNT(*) - COUNT(DISTINCT transaction_id)
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'silver_valid_item_categories',
  COUNTIF(item_category NOT IN ('Electronics', 'Beauty', 'Sports', 'Home', 'Apparel', 'Automotive')) = 0,
  COUNTIF(item_category NOT IN ('Electronics', 'Beauty', 'Sports', 'Home', 'Apparel', 'Automotive'))
FROM retail_silver.cleaned_transactions

UNION ALL

SELECT
  'customer_features_one_row_per_customer',
  COUNT(*) - COUNT(DISTINCT customer_id) = 0,
  COUNT(*) - COUNT(DISTINCT customer_id)
FROM retail_gold.customer_features

UNION ALL

SELECT
  'customer_segments_one_row_per_customer',
  COUNT(*) - COUNT(DISTINCT customer_id) = 0,
  COUNT(*) - COUNT(DISTINCT customer_id)
FROM retail_gold.customer_segments

UNION ALL

SELECT
  'customer_segments_no_null_segment',
  COUNTIF(customer_segment IS NULL) = 0,
  COUNTIF(customer_segment IS NULL)
FROM retail_gold.customer_segments

UNION ALL

SELECT
  'customer_features_non_negative_metrics',
  COUNTIF(
    transaction_count <= 0
    OR total_spend <= 0
    OR avg_transaction_value <= 0
    OR return_rate < 0
    OR return_rate > 1
    OR recency_days < 0
    OR category_diversity <= 0
  ) = 0,
  COUNTIF(
    transaction_count <= 0
    OR total_spend <= 0
    OR avg_transaction_value <= 0
    OR return_rate < 0
    OR return_rate > 1
    OR recency_days < 0
    OR category_diversity <= 0
  )
FROM retail_gold.customer_features

UNION ALL

SELECT
  'gold_all_rows_have_customer_segment',
  COUNTIF(customer_segment IS NULL) = 0,
  COUNTIF(customer_segment IS NULL)
FROM retail_gold.analytics_customer_segments;
