-- =============================================================================
-- GOLD LAYER: Customer Feature Engineering and BQML Model Training
-- =============================================================================
-- Purpose: build customer-level behavioral features and train a BigQuery ML
-- K-means model for customer segmentation.
--
-- Model grain:
-- The model is trained at customer grain, not transaction grain. Each customer
-- receives one stable segment based on spend, frequency, recency, returns, and
-- category preference.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS retail_gold
OPTIONS (
  description = 'Gold layer: business-ready analytics tables and ML models',
  labels = [('layer', 'gold'), ('domain', 'retail')]
);

DROP TABLE IF EXISTS retail_gold.customer_features;

CREATE TABLE retail_gold.customer_features
CLUSTER BY customer_id
OPTIONS (
  description = 'Customer-level features for BQML segmentation',
  labels = [('layer', 'gold'), ('entity', 'customer')]
)
AS
WITH snapshot AS (
  SELECT MAX(purchase_date) AS snapshot_date
  FROM retail_silver.cleaned_transactions
),

customer_aggregates AS (
  SELECT
    t.customer_id,
    COUNT(*) AS transaction_count,
    ROUND(SUM(t.amount), 2) AS total_spend,
    ROUND(AVG(t.amount), 2) AS avg_transaction_value,
    ROUND(MAX(t.amount), 2) AS max_transaction_value,
    MIN(t.purchase_date) AS first_purchase_date,
    MAX(t.purchase_date) AS last_purchase_date,
    DATE_DIFF(MAX(s.snapshot_date), MAX(t.purchase_date), DAY) AS recency_days,
    DATE_DIFF(MAX(t.purchase_date), MIN(t.purchase_date), DAY) AS purchase_span_days,
    ROUND(SAFE_DIVIDE(COUNTIF(t.is_returned), COUNT(*)), 4) AS return_rate,
    ROUND(AVG(t.days_to_first_purchase), 1) AS avg_days_to_purchase,
    COUNT(DISTINCT t.item_category) AS category_diversity,
    SUM(t.amount) AS spend_denominator,
    SUM(IF(t.item_category = 'Beauty', t.amount, 0)) AS beauty_spend,
    SUM(IF(t.item_category = 'Sports', t.amount, 0)) AS sports_spend,
    SUM(IF(t.item_category = 'Home', t.amount, 0)) AS home_spend,
    SUM(IF(t.item_category = 'Apparel', t.amount, 0)) AS apparel_spend,
    SUM(IF(t.item_category = 'Electronics', t.amount, 0)) AS electronics_spend,
    SUM(IF(t.item_category = 'Automotive', t.amount, 0)) AS automotive_spend
  FROM retail_silver.cleaned_transactions AS t
  CROSS JOIN snapshot AS s
  GROUP BY t.customer_id
)

SELECT
  customer_id,
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
  ROUND(SAFE_DIVIDE(beauty_spend, spend_denominator), 4) AS beauty_spend_share,
  ROUND(SAFE_DIVIDE(sports_spend, spend_denominator), 4) AS sports_spend_share,
  ROUND(SAFE_DIVIDE(home_spend, spend_denominator), 4) AS home_spend_share,
  ROUND(SAFE_DIVIDE(apparel_spend, spend_denominator), 4) AS apparel_spend_share,
  ROUND(SAFE_DIVIDE(electronics_spend, spend_denominator), 4) AS electronics_spend_share,
  ROUND(SAFE_DIVIDE(automotive_spend, spend_denominator), 4) AS automotive_spend_share,
  CURRENT_TIMESTAMP() AS _feature_created_at
FROM customer_aggregates;

CREATE OR REPLACE MODEL retail_gold.customer_segmentation_model
OPTIONS (
  model_type = 'kmeans',
  -- Customer-level features support a slightly richer baseline than the
  -- transaction-level model. In production, compare candidate k values with
  -- ML.EVALUATE and business interpretability checks before finalising.
  num_clusters = 5,
  standardize_features = TRUE,
  kmeans_init_method = 'KMEANS++',
  max_iterations = 50,
  distance_type = 'euclidean'
) AS
SELECT
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
  automotive_spend_share
FROM retail_gold.customer_features;
