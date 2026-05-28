-- =============================================================================
-- GOLD LAYER: BQML K-Means Model Training
-- =============================================================================
-- File:    03_gold_model_training.sql
-- Layer:   Gold (Analytics / ML)
-- Purpose: Train a K-means clustering model to segment customers based on
--          their spending amount and product category preferences.
--
-- MODEL CHOICE: K-Means Clustering
--   The task asks us to segment customers — this is an unsupervised learning
--   problem (we don't have labelled "customer segments" to train on). K-means
--   is a natural fit: it groups data points into clusters based on similarity
--   in feature space, letting the data reveal natural customer segments.
--
-- FEATURE SELECTION:
--   - amount (NUMERIC): Captures spending magnitude
--   - item_category (STRING): Captures product preference
--
--   BigQuery ML automatically one-hot encodes STRING features for K-means,
--   so we can pass item_category directly without manual preprocessing.
--
-- KEY DESIGN DECISIONS:
--   1. standardize_features = TRUE
--      This is CRITICAL. K-means uses Euclidean distance, which is sensitive
--      to feature scale. Without standardisation, the amount column (range
--      ~0-1200) would dominate the distance calculation, and the one-hot
--      encoded categories (0/1) would have almost no influence. Standardising
--      puts all features on equal footing.
--
--   2. num_clusters = 4
--      We start with 4 as a reasonable baseline for retail segmentation
--      (think: low-spend/high-spend × product-focused/diversified). In
--      production, you would run an elbow analysis (see commented query below)
--      to find the optimal k by comparing Davies-Bouldin scores across k=2..8.
--
--   3. max_iterations = 20
--      Sufficient for convergence on a 10k-row dataset. Default is 20 in BQML,
--      but being explicit shows intentionality.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Step 1: Create the Gold dataset
-- -----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS retail_gold
OPTIONS (
  description = 'Gold layer: business-ready analytics tables and ML models',
  labels = [('layer', 'gold'), ('domain', 'retail')]
);

-- -----------------------------------------------------------------------------
-- Step 2: Train the K-Means clustering model
-- -----------------------------------------------------------------------------
CREATE OR REPLACE MODEL retail_gold.customer_segmentation_model
OPTIONS (
  model_type = 'kmeans',
  num_clusters = 4,
  standardize_features = TRUE,
  max_iterations = 20,
  distance_type = 'euclidean',
  model_registry = 'vertex_ai',       -- Optional: register in Vertex AI for governance
  description = 'K-means customer segmentation based on spend amount and product category'
) AS
SELECT
  amount,
  item_category
FROM retail_silver.cleaned_transactions;

-- =============================================================================
-- OPTIONAL: Elbow Method for Optimal K
-- =============================================================================
-- In production, you would train multiple models with different cluster counts
-- and compare their Davies-Bouldin Index (lower = better cluster separation).
--
-- Run this BEFORE choosing num_clusters to justify your choice in the interview:
--
-- -- Train models for k=2 through k=8, then compare evaluation metrics.
-- -- Example for k=3:
-- CREATE OR REPLACE MODEL retail_gold._elbow_k3
-- OPTIONS (model_type='kmeans', num_clusters=3, standardize_features=TRUE) AS
-- SELECT amount, item_category FROM retail_silver.cleaned_transactions;
--
-- SELECT 3 AS k, * FROM ML.EVALUATE(MODEL retail_gold._elbow_k3);
--
-- -- Repeat for k=2,4,5,6,7,8 and compare davies_bouldin_index values.
-- -- Pick the k where the index stops improving significantly (the "elbow").
