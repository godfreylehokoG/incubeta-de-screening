-- =============================================================================
-- BRONZE LAYER: Raw Data Ingestion
-- =============================================================================
-- Purpose: create the raw landing table for the source CSV.
--
-- Design decision:
-- The Bronze layer preserves the file as received. All columns are stored as
-- STRING so malformed values, literal "NULL" values, and negative amounts remain
-- available for downstream profiling and cleansing.
-- =============================================================================

-- Bronze dataset.
CREATE SCHEMA IF NOT EXISTS retail_bronze
OPTIONS (
  description = 'Bronze layer: raw, unvalidated data ingested from source systems',
  labels = [('layer', 'bronze'), ('domain', 'retail')]
);

-- Raw landing table.
CREATE OR REPLACE TABLE retail_bronze.raw_transactions (
  transaction_id  STRING  OPTIONS (description = 'Unique transaction identifier (e.g. TXN1001)'),
  customer_id     STRING  OPTIONS (description = 'Customer identifier (e.g. C-2709)'),
  signup_date     STRING  OPTIONS (description = 'Customer signup date as raw string; may contain NULL literals'),
  purchase_date   STRING  OPTIONS (description = 'Transaction purchase date as raw string'),
  amount          STRING  OPTIONS (description = 'Transaction amount as raw string; may contain negatives'),
  item_category   STRING  OPTIONS (description = 'Product category (e.g. Electronics, Beauty, Sports)'),
  is_returned     STRING  OPTIONS (description = 'Return flag as raw string; contains TRUE, FALSE, and NULL literals')
)
OPTIONS (
  description = 'Raw retail transactions ingested from CSV with no transformations applied',
  labels = [('layer', 'bronze'), ('source', 'csv')]
);

-- CSV load options.
-- Recommended production path: upload the CSV to GCS, then run:
--
-- LOAD DATA OVERWRITE retail_bronze.raw_transactions
-- FROM FILES (
--   format = 'CSV',
--   uris = ['gs://YOUR_BUCKET/raw_transactions_10000.csv'],
--   skip_leading_rows = 1
-- );
--
-- Console alternative:
-- Create table from upload, set table name to raw_transactions, paste the schema
-- above, and skip one header row.
--
-- CLI alternative:
-- bq load \
--   --source_format=CSV \
--   --skip_leading_rows=1 \
--   retail_bronze.raw_transactions \
--   ./data/raw_transactions_10000.csv \
--   transaction_id:STRING,customer_id:STRING,signup_date:STRING,purchase_date:STRING,amount:STRING,item_category:STRING,is_returned:STRING

-- Basic ingestion sanity check.
SELECT
  COUNT(*)                                             AS total_rows,
  COUNT(DISTINCT transaction_id)                       AS distinct_transactions,
  COUNTIF(signup_date = 'NULL' OR signup_date IS NULL) AS null_signup_dates,
  COUNTIF(is_returned = 'NULL' OR is_returned IS NULL) AS null_is_returned,
  COUNTIF(SAFE_CAST(amount AS FLOAT64) <= 0)           AS non_positive_amounts
FROM retail_bronze.raw_transactions;

-- Expected:
-- total_rows: 10000
-- distinct_transactions: 10000
-- null_signup_dates: 823
-- null_is_returned: 1009
-- non_positive_amounts: 407
