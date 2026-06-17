-- =============================================================================
-- GOLD LAYER: Model Evaluation & Cluster Interpretation
-- =============================================================================

-- 1. Clustering quality metrics
SELECT *
FROM ML.EVALUATE(MODEL retail_gold.customer_segmentation_model);


-- 2. Centroid interpretation (what defines each cluster)
SELECT
  centroid_id,
  feature,
  numerical_value,
  categorical_value
FROM ML.CENTROIDS(MODEL retail_gold.customer_segmentation_model)
ORDER BY centroid_id, feature;


-- 3. Business-level cluster summary
WITH segment_summary AS (
  SELECT
    customer_segment,
    COUNT(*) AS total_transactions,
    COUNT(DISTINCT customer_id) AS unique_customers,

    ROUND(AVG(amount), 2) AS avg_spend,
    ROUND(MIN(amount), 2) AS min_spend,
    ROUND(MAX(amount), 2) AS max_spend,
    ROUND(STDDEV(amount), 2) AS stddev_spend,

    ROUND(AVG(days_to_first_purchase), 1) AS avg_days_to_purchase,
    ROUND(COUNTIF(is_returned) * 100.0 / COUNT(*), 1) AS return_rate_pct
  FROM retail_gold.analytics_customer_segments
  GROUP BY customer_segment
),

category_counts AS (
  SELECT
    customer_segment,
    item_category,
    COUNT(*) AS category_transactions
  FROM retail_gold.analytics_customer_segments
  GROUP BY customer_segment, item_category
),

dominant_categories AS (
  SELECT
    customer_segment,
    item_category AS dominant_category,
    category_transactions
  FROM category_counts
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY customer_segment
    ORDER BY category_transactions DESC
  ) = 1
)

SELECT
  s.customer_segment,
  s.total_transactions,
  s.unique_customers,
  s.avg_spend,
  s.min_spend,
  s.max_spend,
  s.stddev_spend,
  d.dominant_category,
  d.category_transactions AS dominant_category_transactions,
  s.avg_days_to_purchase,
  s.return_rate_pct
FROM segment_summary s
LEFT JOIN dominant_categories d
  USING (customer_segment)
ORDER BY s.customer_segment;