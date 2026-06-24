

# SandTechnology Warehousing + Migration
#### By Godfrey Lehoko
## 1. Aims & Objectives (2–3 mins)

The goal of this project was to build a reliable and scalable data pipeline to move student performance data from an operational database (MariaDB) into a cloud data warehouse (Redshift) for analytics and reporting.

The business problem was that student data was fragmented across multiple tables and systems, making it difficult for analysts to generate consistent performance insights.

So the objective was to:

* Centralise all student data in Redshift
* Enable near real-time updates using CDC
* Transform raw operational data into analytics-ready datasets
* Support dashboards like student performance reporting in QuickSight

---

## 2. Architecture & Tech Stack (4–5 mins)

The architecture followed a **modern ELT pattern (not ETL)**:

```
MariaDB (OLTP source)
   ↓
AWS DMS (with CDC)
   ↓
Amazon Redshift (raw/staging layer)
   ↓
DBT (transformations inside Redshift)
   ↓
Redshift (analytics layer: facts + dimensions + marts)
   ↓
Quicksight dashboards
```

### Why these tools were used:

* **MariaDB** → Source transactional system (normalized OLTP data)
* **AWS DMS + CDC** → Extract + continuously replicate changes
* **Redshift** → Central data warehouse (scalable columnar storage)
* **DBT** → Transformation layer (SQL-based modelling, testing, version control)
* **Quicksight** → BI consumption layer

### Key design decision:

We chose **ELT instead of ETL** because Redshift is powerful enough to handle transformations at scale, making DBT the ideal transformation tool inside the warehouse.

---

## 3. Your Core Contribution (5–7 mins)

Your main ownership was the **DBT transformation layer and data modelling inside Redshift**.

### You built:

#### 1. Staging layer (stg_)

* Cleaned raw DMS-loaded tables
* Standardised:

  * data types (casts to bigint, decimal, timestamp)
  * strings (trim, lower, null handling)
* Applied defaults:

  * `-99` for missing IDs
  * `0` for counts
  * `'n/a'` for strings

#### 2. Intermediate layer (int_)

* Joined multiple business entities:

  * students
  * classes
  * assessments
  * programmes
  * content
* This layer created **business-ready wide tables**
* Example logic:

  * student + assessment + class → full performance view

#### 3. Marts layer (facts & dimensions)

You implemented a **star schema design**:

### Dimensions:

* dim_students
* dim_classes
* dim_programmes
* dim_content

### Fact tables:

* fact_student_assessments
* fact_student_activity
* fact_performance_metrics

Facts stored measurable events like:

* scores
* attempts
* durations
* completion status

Dimensions stored descriptive context like:

* student demographics
* course metadata
* class structures

---

## 4. Scale & Metrics (2–3 mins)

* Multiple interconnected tables from MariaDB
* CDC ensured continuous ingestion (near real-time updates)
* Data refreshed incrementally instead of full reloads
* Redshift used for scalable analytics queries
* Data volume included:

  * student records
  * assessment submissions
  * activity logs
  * class and programme mappings

### Key complexity:

* Many-to-many relationships (students ↔ classes ↔ assessments)
* Required careful join design to avoid duplication in fact tables

---

## 5. Key Challenges & Failures (4–5 mins)

### Challenge 1: CDC inconsistencies (DMS)

Some updates/deletes were not immediately reflected in Redshift.

**Fix:**

* Revalidated row counts
* Added reconciliation queries in DBT
* Improved monitoring of replication lag

---

### Challenge 2: Data quality issues

* NULL values in key fields
* inconsistent types between MariaDB and Redshift

**Fix:**

* DBT tests (not_null, unique, relationships)
* Standardised casting in staging models
* Default values like -99

---

### Challenge 3: Complex joins causing duplication

Some fact tables were duplicating rows due to incorrect join granularity.

**Fix:**

* Reworked join keys
* Introduced intermediate layer to control grain
* Ensured one row per event in fact tables

---

## 6. Results & Operations (3–4 mins)

The final system delivered:

* Clean, analytics-ready data models in Redshift
* Reliable DBT transformation pipeline
* Star schema supporting fast BI queries
* Automated data validation through DBT tests
* Improved trust in reporting datasets

### Reliability approach:

* DBT tests for every model
* Layered architecture (staging → intermediate → marts)
* Version-controlled transformations
* CDC ensured continuous sync from source

---

## summary

“I built a scalable ELT pipeline using AWS DMS, Redshift, and DBT that transformed raw student operational data into a structured star-schema warehouse powering analytics and reporting.”