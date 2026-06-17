-- =============================================================================
-- GOLD LAYER: Apply Model + Build Analytics Table
-- =============================================================================
-- Purpose:
-- Apply trained model to transaction data and generate cluster assignments.
-- =============================================================================

DROP TABLE IF EXISTS retail_gold.analytics_customer_segments;

CREATE TABLE retail_gold.analytics_customer_segments
PARTITION BY purchase_date
CLUSTER BY customer_segment, item_category
OPTIONS (
  description = 'Transaction-level analytics enriched with ML cluster assignments',
  labels = [('layer', 'gold'), ('model', 'kmeans_v1')]
)
AS
SELECT
  transaction_id,
  customer_id,
  signup_date,
  purchase_date,
  SAFE_CAST(amount AS FLOAT64) AS amount,
  item_category,
  is_returned,
  days_to_first_purchase,

  -- ML output
  CENTROID_ID AS customer_segment,

  -- Metadata
  _processed_at,
  CURRENT_TIMESTAMP() AS _predicted_at

FROM ML.PREDICT(
  MODEL retail_gold.customer_segmentation_model,
  (
    SELECT
      transaction_id,
      customer_id,
      signup_date,
      purchase_date,
      SAFE_CAST(amount AS FLOAT64) AS amount,
      item_category,
      is_returned,
      days_to_first_purchase,
      _processed_at
    FROM retail_silver.cleaned_transactions
  )
);-- =============================================================================
-- GOLD LAYER: Apply Model + Build Analytics Table
-- =============================================================================
-- Purpose:
-- Apply trained model to transaction data and generate cluster assignments.
-- =============================================================================

DROP TABLE IF EXISTS retail_gold.analytics_customer_segments;

CREATE TABLE retail_gold.analytics_customer_segments
PARTITION BY purchase_date
CLUSTER BY customer_segment, item_category
OPTIONS (
  description = 'Transaction-level analytics enriched with ML cluster assignments',
  labels = [('layer', 'gold'), ('model', 'kmeans_v1')]
)
AS
SELECT
  transaction_id,
  customer_id,
  signup_date,
  purchase_date,
  SAFE_CAST(amount AS FLOAT64) AS amount,
  item_category,
  is_returned,
  days_to_first_purchase,

  -- ML output
  CENTROID_ID AS customer_segment,

  -- Metadata
  _processed_at,
  CURRENT_TIMESTAMP() AS _predicted_at

FROM ML.PREDICT(
  MODEL retail_gold.customer_segmentation_model,
  (
    SELECT
      transaction_id,
      customer_id,
      signup_date,
      purchase_date,
      SAFE_CAST(amount AS FLOAT64) AS amount,
      item_category,
      is_returned,
      days_to_first_purchase,
      _processed_at
    FROM retail_silver.cleaned_transactions
  )
);