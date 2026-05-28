-- =============================================================================
-- GOLD LAYER: Generate Predictions & Build Final Analytics Table
-- =============================================================================
-- File:    04_gold_prediction.sql
-- Layer:   Gold (Analytics)
-- Purpose: Apply the trained K-means model to Silver layer data and create
--          the final business-ready analytics table with segment assignments.
--
-- OUTPUT: retail_gold.analytics_customer_segments
--   Every clean transaction enriched with its predicted customer segment.
--   Business users can query this directly for segmentation analysis,
--   targeted marketing, and reporting.
--
-- DESIGN DECISIONS:
--   1. We use TABLE keyword in ML.PREDICT — this passes ALL columns from the
--      Silver table through the prediction, and BigQuery automatically selects
--      the correct feature columns (amount, item_category) for the model.
--      No manual JOIN is needed; all original columns are preserved.
--   2. CENTROID_ID → customer_segment for business readability.
--   3. _predicted_at timestamp for audit trail.
--   4. Table is partitioned and clustered for downstream query performance.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Generate predictions and create the final Gold table
-- -----------------------------------------------------------------------------
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
  -- ML.PREDICT outputs CENTROID_ID (integer 1..k) as the cluster assignment.
  -- We rename it to something business-friendly.
  CENTROID_ID                   AS customer_segment,
  _processed_at,
  CURRENT_TIMESTAMP()           AS _predicted_at
FROM ML.PREDICT(
  MODEL retail_gold.customer_segmentation_model,
  -- The TABLE keyword passes ALL columns through; BigQuery uses only the
  -- model's feature columns (amount, item_category) for prediction and
  -- carries everything else through to the output unchanged.
  TABLE retail_silver.cleaned_transactions
);

-- =============================================================================
-- QUICK VERIFICATION
-- =============================================================================
-- Run after creating the table to verify cluster distribution.

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
