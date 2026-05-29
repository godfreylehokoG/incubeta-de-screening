-- =============================================================================
-- GOLD LAYER: Predictions and Analytics Table
-- =============================================================================
-- Purpose: apply the trained K-means model to Silver transactions and persist
-- the final analytics table with customer segment assignments.
--
-- Design notes:
-- - ML.PREDICT returns the original input columns plus model outputs.
-- - CENTROID_ID is renamed to customer_segment for readability.
-- - _predicted_at records when the segmentation output was generated.
-- =============================================================================

CREATE OR REPLACE TABLE retail_gold.analytics_customer_segments
PARTITION BY purchase_date
CLUSTER BY customer_segment, item_category
OPTIONS (
  description = 'Final analytics table: clean transactions enriched with ML-predicted customer segments',
  labels = [('layer', 'gold'), ('model', 'kmeans_v1')]
)
AS
SELECT
  transaction_id,
  customer_id,
  signup_date,
  purchase_date,
  amount,
  item_category,
  is_returned,
  days_to_first_purchase,
  CENTROID_ID AS customer_segment,
  _processed_at,
  CURRENT_TIMESTAMP() AS _predicted_at
FROM ML.PREDICT(
  MODEL retail_gold.customer_segmentation_model,
  TABLE retail_silver.cleaned_transactions
);

-- Expected verification:
-- SELECT
--   customer_segment,
--   COUNT(*)                              AS num_transactions,
--   ROUND(AVG(amount), 2)                 AS avg_amount,
--   ROUND(MIN(amount), 2)                 AS min_amount,
--   ROUND(MAX(amount), 2)                 AS max_amount,
--   ARRAY_AGG(DISTINCT item_category)     AS categories_in_segment,
--   ROUND(AVG(days_to_first_purchase), 1) AS avg_days_to_purchase,
--   COUNTIF(is_returned)                  AS returns_count
-- FROM retail_gold.analytics_customer_segments
-- GROUP BY customer_segment
-- ORDER BY customer_segment;
