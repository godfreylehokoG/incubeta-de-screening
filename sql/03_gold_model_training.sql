-- =============================================================================
-- GOLD LAYER: BQML K-Means Model Training
-- =============================================================================
-- Purpose: train a BigQuery ML K-means model for customer segmentation.
--
-- Features:
-- - amount: spending magnitude.
-- - item_category: product preference, one-hot encoded automatically by BQML.
--
-- Model settings:
-- - num_clusters = 4 as a simple baseline for retail segmentation.
-- - standardize_features = TRUE so amount does not dominate distance scoring.
-- - max_iterations = 20, sufficient for this 10k-row assessment dataset.
-- =============================================================================

-- Gold dataset.
CREATE SCHEMA IF NOT EXISTS retail_gold
OPTIONS (
  description = 'Gold layer: business-ready analytics tables and ML models',
  labels = [('layer', 'gold'), ('domain', 'retail')]
);

-- K-means model training.
CREATE OR REPLACE MODEL retail_gold.customer_segmentation_model
OPTIONS (
  model_type = 'kmeans',
  num_clusters = 4,
  standardize_features = TRUE,
  max_iterations = 20,
  distance_type = 'euclidean'
) AS
SELECT
  amount,
  item_category
FROM retail_silver.cleaned_transactions;

-- Optional elbow-method exploration:
-- Train additional models with num_clusters from 2 to 8 and compare
-- ML.EVALUATE results, especially davies_bouldin_index.
