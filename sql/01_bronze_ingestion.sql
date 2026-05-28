-- =============================================================================
-- BRONZE LAYER: Raw Data Ingestion
-- =============================================================================
-- File:    01_bronze_ingestion.sql
-- Layer:   Bronze (Raw / Landing)
-- Purpose: Ingest the raw CSV exactly as-is into BigQuery with no transformations.
--
-- DESIGN DECISION:
--   The Bronze layer is our "single source of truth" — a faithful copy of the
--   source data. We intentionally load ALL columns as STRING to preserve the
--   raw values (including malformed data, string "NULL" literals, negative
--   amounts, etc.). This ensures we never lose information during ingestion
--   and can always trace data quality issues back to the source.
--
--   Type casting and cleansing happen downstream in the Silver layer, keeping
--   concerns cleanly separated.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Step 1: Create the Bronze dataset
-- -----------------------------------------------------------------------------
-- Using a descriptive dataset with a default location.
-- In production, you would set the location to match your organisation's
-- data residency requirements (e.g., EU, US, asia-southeast1).
CREATE SCHEMA IF NOT EXISTS retail_bronze
OPTIONS (
  description = 'Bronze layer: raw, unvalidated data ingested from source systems',
  labels = [('layer', 'bronze'), ('domain', 'retail')]
);

-- -----------------------------------------------------------------------------
-- Step 2: Create the raw_transactions table
-- -----------------------------------------------------------------------------
-- All columns are STRING — this is deliberate. We want a schema-on-read
-- approach at the Bronze level so the pipeline doesn't fail on unexpected
-- data formats or edge cases in the source file.
CREATE OR REPLACE TABLE retail_bronze.raw_transactions (
  transaction_id  STRING  OPTIONS (description = 'Unique transaction identifier (e.g. TXN1001)'),
  customer_id     STRING  OPTIONS (description = 'Customer identifier (e.g. C-2709)'),
  signup_date     STRING  OPTIONS (description = 'Customer signup date as raw string — may contain NULL literals'),
  purchase_date   STRING  OPTIONS (description = 'Transaction purchase date as raw string'),
  amount          STRING  OPTIONS (description = 'Transaction amount as raw string — may contain negatives'),
  item_category   STRING  OPTIONS (description = 'Product category (e.g. Electronics, Beauty, Sports)'),
  is_returned     STRING  OPTIONS (description = 'Return flag as raw string — contains TRUE, FALSE, and NULL literals')
)
OPTIONS (
  description = 'Raw retail transactions ingested from CSV with no transformations applied',
  labels = [('layer', 'bronze'), ('source', 'csv')]
);

-- -----------------------------------------------------------------------------
-- Step 3: Load data from CSV
-- -----------------------------------------------------------------------------
-- OPTION A: Load from Google Cloud Storage (recommended for production)
-- Upload the CSV to a GCS bucket first, then load:
--
-- LOAD DATA OVERWRITE retail_bronze.raw_transactions
-- FROM FILES (
--   format = 'CSV',
--   uris = ['gs://YOUR_BUCKET/raw_transactions_10000.csv'],
--   skip_leading_rows = 1
-- );
--
-- OPTION B: Load via the BigQuery Console UI
-- 1. Navigate to retail_bronze dataset
-- 2. Click "Create Table" → Source: Upload → Select raw_transactions_10000.csv
-- 3. Table name: raw_transactions
-- 4. Schema: Edit as text → paste the column definitions above (all STRING)
-- 5. Advanced → Header rows to skip: 1
--
-- OPTION C: Load using the bq CLI tool
-- bq load \
--   --source_format=CSV \
--   --skip_leading_rows=1 \
--   retail_bronze.raw_transactions \
--   ./raw_transactions_10000.csv \
--   transaction_id:STRING,customer_id:STRING,signup_date:STRING,purchase_date:STRING,amount:STRING,item_category:STRING,is_returned:STRING

-- -----------------------------------------------------------------------------
-- Step 4: Quick sanity check after ingestion
-- -----------------------------------------------------------------------------
-- Verify we loaded all 10,000 rows and the data looks as expected.
SELECT
  COUNT(*)                                          AS total_rows,
  COUNT(DISTINCT transaction_id)                    AS distinct_transactions,
  COUNTIF(signup_date = 'NULL' OR signup_date IS NULL) AS null_signup_dates,
  COUNTIF(is_returned = 'NULL' OR is_returned IS NULL) AS null_is_returned,
  COUNTIF(SAFE_CAST(amount AS FLOAT64) <= 0)        AS non_positive_amounts
FROM retail_bronze.raw_transactions;

-- Expected output:
-- total_rows: 10000
-- distinct_transactions: 10000
-- null_signup_dates: 823
-- null_is_returned: 1009
-- non_positive_amounts: 407
