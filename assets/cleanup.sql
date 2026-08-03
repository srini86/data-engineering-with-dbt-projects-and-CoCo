-- ============================================================================
-- cleanup.sql
-- Tears down every object this lab created.
-- Paste into a new Workspace SQL file and click "Run All". No CLI needed.
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- Suspend Task first, so scheduled runs stop cleanly
ALTER TASK IF EXISTS tasty_bytes_dbt_db.prod.tb_dbt_build_task SUSPEND;

-- Suspend the alert
ALTER ALERT IF EXISTS tasty_bytes_dbt_db.prod.tb_dbt_alert SUSPEND;

-- Suspend the warehouse before dropping it
ALTER WAREHOUSE IF EXISTS tasty_bytes_dbt_wh SUSPEND;

-- The dbt project object must be dropped explicitly
DROP DBT PROJECT IF EXISTS tasty_bytes_dbt_db.prod.tasty_bytes_dbt_project;

-- Dropping the database removes Tasks, Alert, tables/schemas in one step
DROP DATABASE IF EXISTS tasty_bytes_dbt_db;
DROP WAREHOUSE IF EXISTS tasty_bytes_dbt_wh;

-- Integrations live at the account level (not inside the DB)
DROP NOTIFICATION INTEGRATION IF EXISTS tb_dbt_email_notifications;
DROP EXTERNAL ACCESS INTEGRATION IF EXISTS dbt_deps_eai;

-- ----------------------------------------------------------------------
-- Validate: all should return zero rows
-- ----------------------------------------------------------------------
SHOW DATABASES LIKE 'tasty_bytes_dbt%';
SHOW WAREHOUSES LIKE 'tasty_bytes_dbt%';
SHOW NOTIFICATION INTEGRATIONS LIKE 'tb_dbt%';
SHOW EXTERNAL ACCESS INTEGRATIONS LIKE 'dbt_deps%';
