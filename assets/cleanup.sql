-- ============================================================================
-- cleanup.sql
-- Tears down every NZBANK_ object this lab created.
-- Paste into a new Workspace SQL file and click "Run All". No CLI needed.
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- Suspend Tasks first, so scheduled runs stop cleanly
ALTER TASK IF EXISTS NZBANK_HOL.PROD.NZBANK_TEST_DBT_TASK SUSPEND;
ALTER TASK IF EXISTS NZBANK_HOL.PROD.NZBANK_RUN_DBT_TASK SUSPEND;

-- Suspend the alert
ALTER ALERT IF EXISTS NZBANK_HOL.PROD.NZBANK_DBT_ALERT SUSPEND;

-- Suspend the warehouse before dropping it
ALTER WAREHOUSE IF EXISTS NZBANK_WH SUSPEND;

-- Dropping the database removes Tasks, Alert, tables/schemas in one step.
-- The dbt project object must be dropped explicitly first.
DROP DBT PROJECT IF EXISTS NZBANK_HOL.PROD.NZBANK_DBT_PROJECT;
DROP DATABASE IF EXISTS NZBANK_HOL;
DROP WAREHOUSE IF EXISTS NZBANK_WH;

-- Notification integration and EAI live at the account level (not inside the DB)
DROP NOTIFICATION INTEGRATION IF EXISTS NZBANK_EMAIL_NOTIFICATIONS;
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS DBT_DEPS_EAI;

-- ----------------------------------------------------------------------
-- Validate: all three should return zero rows
-- ----------------------------------------------------------------------
SHOW DATABASES LIKE 'NZBANK%';
SHOW WAREHOUSES LIKE 'NZBANK%';
SHOW NOTIFICATION INTEGRATIONS LIKE 'NZBANK%';
