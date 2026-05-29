-- =============================================================================
-- GOLD LAYER: Model Evaluation and Cluster Interpretation
-- =============================================================================
-- Purpose: evaluate the trained K-means model and summarize the resulting
-- customer segments.
-- =============================================================================

-- Query 1: clustering quality metrics.
-- Lower davies_bouldin_index and mean_squared_distance values indicate tighter,
-- better-separated clusters.
SELECT
  'K-Means Customer Segmentation' AS model_name,
  4                               AS num_clusters,
  *
FROM ML.EVALUATE(MODEL retail_gold.customer_segmentation_model);

-- Query 2: centroid details for interpreting cluster drivers.
SELECT
  centroid_id,
  feature,
  numerical_value,
  categorical_value
FROM ML.CENTROIDS(MODEL retail_gold.customer_segmentation_model)
ORDER BY centroid_id, feature;

-- Query 3: business-facing segment summary.
SELECT
  customer_segment,
  COUNT(*)                                          AS total_transactions,
  COUNT(DISTINCT customer_id)                       AS unique_customers,
  ROUND(AVG(amount), 2)                             AS avg_spend,
  ROUND(MIN(amount), 2)                             AS min_spend,
  ROUND(MAX(amount), 2)                             AS max_spend,
  ROUND(STDDEV(amount), 2)                          AS stddev_spend,
  (SELECT cat FROM UNNEST(cats) AS cat
   GROUP BY cat ORDER BY COUNT(*) DESC LIMIT 1)     AS dominant_category,
  ROUND(AVG(days_to_first_purchase), 1)             AS avg_days_to_purchase,
  ROUND(COUNTIF(is_returned) * 100.0 / COUNT(*), 1) AS return_rate_pct
FROM retail_gold.analytics_customer_segments,
  UNNEST([item_category]) AS cats
GROUP BY customer_segment
ORDER BY customer_segment;
