-- =============================================================================
-- VALIDATION: Row Count Reconciliation Across Layers
-- =============================================================================
-- Purpose: verify row-level reconciliation across Bronze, Silver, and Gold,
-- plus customer-level reconciliation for the segmentation model inputs/outputs.
-- =============================================================================

WITH bronze_counts AS (
  SELECT
    COUNT(*) AS bronze_total,
    COUNTIF(
      SAFE_CAST(NULLIF(TRIM(amount), 'NULL') AS NUMERIC) <= 0
      OR SAFE_CAST(NULLIF(TRIM(amount), 'NULL') AS NUMERIC) IS NULL
    ) AS bronze_invalid_amounts,
    COUNTIF(
      TRIM(purchase_date) = 'NULL'
      OR TRIM(purchase_date) = ''
      OR purchase_date IS NULL
    ) AS bronze_null_purchase_dates
  FROM retail_bronze.raw_transactions
),

silver_counts AS (
  SELECT
    COUNT(*) AS silver_total,
    COUNT(DISTINCT customer_id) AS silver_customers
  FROM retail_silver.cleaned_transactions
),

customer_feature_counts AS (
  SELECT COUNT(*) AS customer_feature_total
  FROM retail_gold.customer_features
),

customer_segment_counts AS (
  SELECT COUNT(*) AS customer_segment_total
  FROM retail_gold.customer_segments
),

gold_counts AS (
  SELECT
    COUNT(*) AS gold_total,
    COUNT(DISTINCT customer_id) AS gold_customers
  FROM retail_gold.analytics_customer_segments
)

SELECT
  b.bronze_total,
  b.bronze_invalid_amounts,
  b.bronze_null_purchase_dates,
  b.bronze_invalid_amounts + b.bronze_null_purchase_dates AS expected_filtered_rows,
  s.silver_total,
  b.bronze_total - s.silver_total AS actual_filtered_rows,
  s.silver_customers,
  cf.customer_feature_total,
  cs.customer_segment_total,
  g.gold_total,
  g.gold_customers,
  s.silver_total - g.gold_total AS silver_to_gold_row_diff,
  s.silver_customers - g.gold_customers AS silver_to_gold_customer_diff,
  s.silver_customers - cf.customer_feature_total AS silver_to_features_customer_diff,
  s.silver_customers - cs.customer_segment_total AS silver_to_segments_customer_diff,
  (s.silver_total > 0) AS silver_has_data,
  (g.gold_total = s.silver_total) AS gold_matches_silver_rows,
  (g.gold_customers = s.silver_customers) AS gold_matches_silver_customers,
  (cf.customer_feature_total = s.silver_customers) AS features_match_silver_customers,
  (cs.customer_segment_total = s.silver_customers) AS segments_match_silver_customers,
  (b.bronze_total - s.silver_total >= b.bronze_invalid_amounts) AS filtered_count_valid
FROM bronze_counts AS b
CROSS JOIN silver_counts AS s
CROSS JOIN customer_feature_counts AS cf
CROSS JOIN customer_segment_counts AS cs
CROSS JOIN gold_counts AS g;

-- Expected:
-- bronze_total: 10000
-- silver_total: 9593
-- silver_customers: 4789
-- customer_feature_total: 4789
-- customer_segment_total: 4789
-- gold_total: 9593
