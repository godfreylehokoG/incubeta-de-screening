-- =============================================================================
-- GOLD LAYER: Model Evaluation & Cluster Interpretation
-- =============================================================================
-- File:    05_gold_model_evaluation.sql
-- Layer:   Gold (Analytics / ML)
-- Purpose: Evaluate the trained K-means model and inspect cluster centroids
--          to understand what each customer segment represents.
--
-- WHY THIS MATTERS:
--   Training a model is only half the job. A senior DE knows you need to:
--   1. EVALUATE — Is the model producing meaningful clusters?
--   2. INTERPRET — What does each cluster actually represent in business terms?
--   3. DOCUMENT — Provide evidence for stakeholders that the model is useful.
--
--   The output from these queries should be screenshot'd for the /proof folder.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Query 1: Model Evaluation Metrics
-- -----------------------------------------------------------------------------
-- ML.EVALUATE returns standard clustering metrics:
--   - davies_bouldin_index: Measures cluster separation (LOWER = better).
--     Values < 1.0 indicate well-separated clusters.
--   - mean_squared_distance: Average distance of points to their centroid
--     (LOWER = tighter clusters).
--
-- INTERVIEW TALKING POINT:
--   "I evaluated the model using the Davies-Bouldin Index, which measures
--    how well-separated the clusters are. A score below 1.0 indicates good
--    separation, meaning our segments are genuinely distinct."

SELECT
  'K-Means Customer Segmentation' AS model_name,
  4                                AS num_clusters,
  *
FROM ML.EVALUATE(MODEL retail_gold.customer_segmentation_model);

-- -----------------------------------------------------------------------------
-- Query 2: Cluster Centroid Details
-- -----------------------------------------------------------------------------
-- ML.CENTROIDS shows the "centre" of each cluster — the average feature
-- values that define each segment. This is how we translate cluster IDs
-- into business-meaningful segment names.
--
-- For example, if Centroid 1 has a high average amount and is dominated by
-- "Electronics", we might label it "High-Spend Electronics Enthusiasts".

SELECT
  centroid_id,
  feature,
  numerical_value,
  categorical_value
FROM ML.CENTROIDS(MODEL retail_gold.customer_segmentation_model)
ORDER BY centroid_id, feature;

-- -----------------------------------------------------------------------------
-- Query 3: Cluster Distribution Summary
-- -----------------------------------------------------------------------------
-- This gives us a business-friendly view of each segment: how many customers,
-- what they spend, what they buy, how quickly they convert.
-- Perfect for a slide or stakeholder report.

SELECT
  customer_segment,
  COUNT(*)                                          AS total_transactions,
  COUNT(DISTINCT customer_id)                       AS unique_customers,
  ROUND(AVG(amount), 2)                             AS avg_spend,
  ROUND(MIN(amount), 2)                             AS min_spend,
  ROUND(MAX(amount), 2)                             AS max_spend,
  ROUND(STDDEV(amount), 2)                          AS stddev_spend,
  -- Most common category per segment
  (SELECT cat FROM UNNEST(cats) AS cat
   GROUP BY cat ORDER BY COUNT(*) DESC LIMIT 1)     AS dominant_category,
  ROUND(AVG(days_to_first_purchase), 1)             AS avg_days_to_purchase,
  ROUND(COUNTIF(is_returned) * 100.0 / COUNT(*), 1) AS return_rate_pct
FROM retail_gold.analytics_customer_segments,
  UNNEST([item_category]) AS cats
GROUP BY customer_segment
ORDER BY customer_segment;

-- =============================================================================
-- INTERVIEW NARRATIVE:
-- =============================================================================
-- When walking through this in the interview, structure it as:
--
-- 1. "First, I checked the model quality using ML.EVALUATE. The Davies-Bouldin
--     Index of [X] tells us the clusters are [well/poorly] separated."
--
-- 2. "Then I used ML.CENTROIDS to understand what each cluster represents.
--     For example, Cluster 1 centres around [amount] spend in [category],
--     so I'd label these customers as [business-friendly name]."
--
-- 3. "Finally, I built a distribution summary showing the practical differences
--     between segments — average spend, conversion speed, return rates —
--     which is what a marketing team would actually use."
-- =============================================================================
