-- =============================================================================
-- GOLD LAYER: Model Evaluation and Customer Segment Interpretation
-- =============================================================================
-- Purpose: evaluate the customer-level K-means model and summarize the
-- behavioral profile of each customer segment.
-- =============================================================================

-- Query 1: clustering quality metrics.
-- Lower davies_bouldin_index and mean_squared_distance values indicate tighter,
-- better-separated clusters.
SELECT
  'Customer-Level K-Means Segmentation' AS model_name,
  5 AS num_clusters,
  *
FROM ML.EVALUATE(MODEL retail_gold.customer_segmentation_model);

-- Query 2: centroid details for interpreting cluster drivers.
SELECT
  centroid_id,
  feature,
  ROUND(numerical_value, 4) AS numerical_value
FROM ML.CENTROIDS(MODEL retail_gold.customer_segmentation_model)
ORDER BY centroid_id, feature;

-- Query 3: customer-level segment summary.
WITH segment_summary AS (
  SELECT
    customer_segment,
    COUNT(*) AS total_customers,
    SUM(transaction_count) AS total_transactions,
    ROUND(AVG(total_spend), 2) AS avg_customer_total_spend,
    ROUND(AVG(avg_transaction_value), 2) AS avg_transaction_value,
    ROUND(AVG(transaction_count), 2) AS avg_transactions_per_customer,
    ROUND(AVG(return_rate) * 100, 1) AS avg_return_rate_pct,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(avg_days_to_purchase), 1) AS avg_days_to_purchase,
    ROUND(AVG(category_diversity), 2) AS avg_category_diversity
  FROM retail_gold.customer_segments
  GROUP BY customer_segment
),

category_preferences AS (
  SELECT customer_segment, 'Beauty' AS item_category, AVG(beauty_spend_share) AS avg_spend_share
  FROM retail_gold.customer_segments
  GROUP BY customer_segment

  UNION ALL

  SELECT customer_segment, 'Sports', AVG(sports_spend_share)
  FROM retail_gold.customer_segments
  GROUP BY customer_segment

  UNION ALL

  SELECT customer_segment, 'Home', AVG(home_spend_share)
  FROM retail_gold.customer_segments
  GROUP BY customer_segment

  UNION ALL

  SELECT customer_segment, 'Apparel', AVG(apparel_spend_share)
  FROM retail_gold.customer_segments
  GROUP BY customer_segment

  UNION ALL

  SELECT customer_segment, 'Electronics', AVG(electronics_spend_share)
  FROM retail_gold.customer_segments
  GROUP BY customer_segment

  UNION ALL

  SELECT customer_segment, 'Automotive', AVG(automotive_spend_share)
  FROM retail_gold.customer_segments
  GROUP BY customer_segment
),

dominant_categories AS (
  SELECT
    customer_segment,
    ARRAY_AGG(
      STRUCT(item_category, avg_spend_share)
      ORDER BY avg_spend_share DESC, item_category
      LIMIT 1
    )[OFFSET(0)] AS dominant_category
  FROM category_preferences
  GROUP BY customer_segment
)

SELECT
  s.customer_segment,
  s.total_customers,
  s.total_transactions,
  s.avg_customer_total_spend,
  s.avg_transaction_value,
  s.avg_transactions_per_customer,
  s.avg_return_rate_pct,
  s.avg_recency_days,
  s.avg_days_to_purchase,
  s.avg_category_diversity,
  d.dominant_category.item_category AS dominant_category,
  ROUND(d.dominant_category.avg_spend_share * 100, 1) AS dominant_category_spend_share_pct
FROM segment_summary AS s
LEFT JOIN dominant_categories AS d
  USING (customer_segment)
ORDER BY s.customer_segment;
