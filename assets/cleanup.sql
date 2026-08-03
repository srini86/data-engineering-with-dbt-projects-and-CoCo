-- ============================================================================
-- cleanup.sql
-- Tears down every object this lab created.
-- Paste into a new Workspace SQL file and click "Run All". No CLI needed.
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- Suspend Task first, so scheduled runs stop cleanly
ALTER TASK IF EXISTS NZBANK_HOL.prod.NZBANK_DBT_BUILD_TASK SUSPEND;

-- Suspend the alert
ALTER ALERT IF EXISTS NZBANK_HOL.prod.NZBANK_DBT_ALERT SUSPEND;

-- Suspend the warehouse before dropping it
ALTER WAREHOUSE IF EXISTS NZBANK_WH SUSPEND;

-- The dbt project object must be dropped explicitly
DROP DBT PROJECT IF EXISTS NZBANK_HOL.prod.NZBANK_DBT_PROJECT;

-- Dropping the database removes Tasks, Alert, tables/schemas in one step
DROP DATABASE IF EXISTS NZBANK_HOL;
DROP WAREHOUSE IF EXISTS NZBANK_WH;

-- Integrations live at the account level (not inside the DB)
DROP NOTIFICATION INTEGRATION IF EXISTS NZBANK_EMAIL_NOTIFICATIONS;
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS DBT_DEPS_EAI;

-- ----------------------------------------------------------------------
-- Validate: all should return zero rows
-- ----------------------------------------------------------------------
SHOW DATABASES LIKE 'NZBANK%';
SHOW WAREHOUSES LIKE 'NZBANK%';
SHOW NOTIFICATION INTEGRATIONS LIKE 'tb_dbt%';
SHOW EXTERNAL ACCESS INTEGRATIONS LIKE 'DBT_DEPS%';
