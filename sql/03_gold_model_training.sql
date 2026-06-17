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
-- - num_clusters = 5 as a simple baseline for retail segmentation.
-- - standardize_features = TRUE so amount does not dominate distance scoring.
-- - max_iterations = 50, sufficient for this 10k-row assessment dataset.
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
  num_clusters = 5,
  standardize_features = TRUE,
  kmeans_init_method = 'KMEANS++',
  max_iterations = 50,
  distance_type = 'euclidean'
) AS
SELECT
  SAFE_CAST(amount AS FLOAT64) AS amount,
  item_category
FROM retail_silver.cleaned_transactions;