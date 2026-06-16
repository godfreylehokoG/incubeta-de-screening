-- =============================================================================
-- GOLD LAYER: Customer Segment Predictions
-- =============================================================================
-- Purpose:
-- Apply trained K-means model (customer-level) to generate stable
-- customer segment assignments, then prepare for downstream analytics.
--
-- Key design principle:
-- Prediction is done at CUSTOMER grain (same as training), then can be
-- joined back to transactions for reporting.
-- =============================================================================

DROP TABLE IF EXISTS retail_gold.customer_segments;

CREATE TABLE retail_gold.customer_segments
OPTIONS (
  description = 'Customer-level ML segment assignments using K-means model',
  labels = [('layer', 'gold'), ('model', 'kmeans_customer_v1')]
)
AS
SELECT
  customer_id,
  CENTROID_ID AS customer_segment,

  -- Original features used for traceability
  transaction_count,
  total_spend,
  avg_transaction_value,
  max_transaction_value,
  recency_days,
  purchase_span_days,
  return_rate,
  avg_days_to_purchase,
  category_diversity,

  beauty_spend_share,
  sports_spend_share,
  home_spend_share,
  apparel_spend_share,
  electronics_spend_share,
  automotive_spend_share,

  -- Metadata
  CURRENT_TIMESTAMP() AS _predicted_at

FROM ML.PREDICT(
  MODEL retail_gold.customer_segmentation_model,
  TABLE retail_gold.customer_features
);


