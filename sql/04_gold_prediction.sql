-- =============================================================================
-- GOLD LAYER: Customer Segments and Analytics Table
-- =============================================================================
-- Purpose: apply the customer-level K-means model and persist the final Gold
-- analytics table with clean transaction rows enriched by customer segment.
-- =============================================================================

DROP TABLE IF EXISTS retail_gold.customer_segments;

CREATE TABLE retail_gold.customer_segments
CLUSTER BY customer_segment
OPTIONS (
  description = 'Customer-level BQML segment assignments and segmentation features',
  labels = [('layer', 'gold'), ('entity', 'customer')]
)
AS
SELECT
  customer_id,
  CENTROID_ID AS customer_segment,
  transaction_count,
  total_spend,
  avg_transaction_value,
  max_transaction_value,
  first_purchase_date,
  last_purchase_date,
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
  CURRENT_TIMESTAMP() AS _predicted_at
FROM ML.PREDICT(
  MODEL retail_gold.customer_segmentation_model,
  TABLE retail_gold.customer_features
);

DROP TABLE IF EXISTS retail_gold.analytics_customer_segments;

CREATE TABLE retail_gold.analytics_customer_segments
PARTITION BY purchase_date
CLUSTER BY customer_segment, item_category
OPTIONS (
  description = 'Clean transaction rows enriched with customer-level ML segment assignments',
  labels = [('layer', 'gold'), ('model', 'kmeans_customer_v2')]
)
AS
SELECT
  t.transaction_id,
  t.customer_id,
  t.signup_date,
  t.purchase_date,
  t.amount,
  t.item_category,
  t.is_returned,
  t.days_to_first_purchase,
  s.customer_segment,
  s.transaction_count AS customer_transaction_count,
  s.total_spend AS customer_total_spend,
  s.avg_transaction_value AS customer_avg_transaction_value,
  s.max_transaction_value AS customer_max_transaction_value,
  s.recency_days AS customer_recency_days,
  s.purchase_span_days AS customer_purchase_span_days,
  s.return_rate AS customer_return_rate,
  s.avg_days_to_purchase AS customer_avg_days_to_purchase,
  s.category_diversity AS customer_category_diversity,
  s.beauty_spend_share,
  s.sports_spend_share,
  s.home_spend_share,
  s.apparel_spend_share,
  s.electronics_spend_share,
  s.automotive_spend_share,
  t._processed_at,
  s._predicted_at
FROM retail_silver.cleaned_transactions AS t
INNER JOIN retail_gold.customer_segments AS s
  USING (customer_id);

-- Expected verification:
-- SELECT
--   customer_segment,
--   COUNT(*) AS num_transactions,
--   COUNT(DISTINCT customer_id) AS num_customers,
--   ROUND(AVG(amount), 2) AS avg_transaction_amount,
--   ROUND(AVG(customer_total_spend), 2) AS avg_customer_total_spend,
--   ROUND(AVG(customer_return_rate) * 100, 1) AS avg_customer_return_rate_pct
-- FROM retail_gold.analytics_customer_segments
-- GROUP BY customer_segment
-- ORDER BY customer_segment;
