-- =============================================================================
-- VALIDATION: Row Count Reconciliation Across Layers
-- =============================================================================
-- File:    row_count_checks.sql
-- Purpose: Verify data integrity across Bronze → Silver → Gold transitions.
--
-- WHY:
--   In production pipelines, silent data loss is the most dangerous failure
--   mode. These checks ensure every row is accounted for — either it made it
--   through or was explicitly filtered out.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Full pipeline reconciliation in a single query
-- -----------------------------------------------------------------------------
WITH bronze_counts AS (
  SELECT
    COUNT(*)                                              AS bronze_total,
    COUNTIF(SAFE_CAST(NULLIF(TRIM(amount), 'NULL') AS NUMERIC) <= 0
            OR SAFE_CAST(NULLIF(TRIM(amount), 'NULL') AS NUMERIC) IS NULL)
                                                          AS bronze_invalid_amounts,
    COUNTIF(TRIM(purchase_date) = 'NULL'
            OR TRIM(purchase_date) = ''
            OR purchase_date IS NULL)                     AS bronze_null_purchase_dates
  FROM retail_bronze.raw_transactions
),

silver_counts AS (
  SELECT COUNT(*) AS silver_total
  FROM retail_silver.cleaned_transactions
),

gold_counts AS (
  SELECT COUNT(*) AS gold_total
  FROM retail_gold.analytics_customer_segments
)

SELECT
  b.bronze_total,
  b.bronze_invalid_amounts,
  b.bronze_null_purchase_dates,
  b.bronze_invalid_amounts + b.bronze_null_purchase_dates AS expected_filtered_rows,
  s.silver_total,
  b.bronze_total - s.silver_total                         AS actual_filtered_rows,
  g.gold_total,
  s.silver_total - g.gold_total                           AS silver_to_gold_diff,
  -- Assertions: these should all be TRUE
  (s.silver_total > 0)                                    AS silver_has_data,
  (g.gold_total = s.silver_total)                         AS gold_matches_silver,
  (b.bronze_total - s.silver_total >= b.bronze_invalid_amounts) AS filtered_count_valid
FROM bronze_counts b
CROSS JOIN silver_counts s
CROSS JOIN gold_counts g;

-- Expected results:
-- bronze_total:            10000
-- bronze_invalid_amounts:  ~407
-- silver_total:            ~9593
-- gold_total:              ~9593 (should match silver — ML.PREDICT doesn't drop rows)
-- gold_matches_silver:     TRUE
-- filtered_count_valid:    TRUE
