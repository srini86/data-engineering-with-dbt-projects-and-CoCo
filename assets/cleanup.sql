-- ============================================================================
-- cleanup.sql
-- Tears down every NZBANK_ object this lab created.
-- Paste into a new Workspace SQL file and click "Run All". No CLI needed.
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- Suspend Tasks first, so scheduled runs stop cleanly
ALTER TASK IF EXISTS NZBANK_HOL.PROD.NZBANK_TEST_DBT_TASK SUSPEND;
ALTER TASK IF EXISTS NZBANK_HOL.PROD.NZBANK_RUN_DBT_TASK SUSPEND;

-- Suspend the warehouse before dropping it
ALTER WAREHOUSE IF EXISTS NZBANK_WH SUSPEND;

-- Dropping the database removes the DBT PROJECT object, Tasks, Alert,
-- and all tables/schemas in one step
DROP DATABASE IF EXISTS NZBANK_HOL;
DROP WAREHOUSE IF EXISTS NZBANK_WH;

-- ----------------------------------------------------------------------
-- Validate: all three should return zero rows
-- ----------------------------------------------------------------------
SHOW DATABASES LIKE 'NZBANK%';
SHOW WAREHOUSES LIKE 'NZBANK%';
