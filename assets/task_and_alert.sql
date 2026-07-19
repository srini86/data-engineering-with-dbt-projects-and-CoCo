-- ============================================================================
-- task_and_alert.sql
-- Reference SQL for Module 03 (Deploy and Operate).
--
-- In the lab you create the schedule via the "Create Schedule" button on the
-- dbt project's Project Details page in Snowsight -- this file is the SQL
-- that button generates, kept here for reference and for the CI/CD mapping
-- discussion (this is exactly what your AWS CodePipeline step would run).
-- Adapted from https://www.snowflake.com/en/developers/guides/dbt-projects-on-snowflake/
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE NZBANK_WH;

-- ----------------------------------------------------------------------
-- Task 1: Run the dbt project daily at 06:00 UTC
-- ----------------------------------------------------------------------
CREATE OR ALTER TASK NZBANK_HOL.PROD.NZBANK_RUN_DBT_TASK
    WAREHOUSE = NZBANK_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'
AS
    EXECUTE DBT PROJECT NZBANK_HOL.PROD.NZBANK_DBT_PROJECT
        ARGS = 'run --target prod';

-- ----------------------------------------------------------------------
-- Task 2: Test run, chained after Task 1 completes
-- ----------------------------------------------------------------------
CREATE OR ALTER TASK NZBANK_HOL.PROD.NZBANK_TEST_DBT_TASK
    WAREHOUSE = NZBANK_WH
    AFTER NZBANK_HOL.PROD.NZBANK_RUN_DBT_TASK
AS
    EXECUTE DBT PROJECT NZBANK_HOL.PROD.NZBANK_DBT_PROJECT
        ARGS = 'test --target prod';

-- Tasks are created suspended. Resume the child before the root.
ALTER TASK NZBANK_HOL.PROD.NZBANK_TEST_DBT_TASK RESUME;
ALTER TASK NZBANK_HOL.PROD.NZBANK_RUN_DBT_TASK RESUME;

-- Run once immediately to confirm the chain works, rather than waiting
-- for the next scheduled window.
EXECUTE TASK NZBANK_HOL.PROD.NZBANK_RUN_DBT_TASK;

-- ----------------------------------------------------------------------
-- Alert: notify on test failure.
-- NOTE: verify your email in Snowsight first (user icon > Profile > email),
-- and replace <YOUR EMAIL HERE> below before running.
-- ----------------------------------------------------------------------
CREATE OR REPLACE ALERT NZBANK_HOL.PROD.NZBANK_DBT_ALERT
    SCHEDULE = '60 MINUTE'
    IF (EXISTS (
        SELECT NAME, SCHEMA_NAME
        FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
            SCHEDULED_TIME_RANGE_START => (GREATEST(
                TIMEADD('day', -1, CURRENT_TIMESTAMP()),
                SNOWFLAKE.ALERT.LAST_SUCCESSFUL_SCHEDULED_TIME()
            )),
            SCHEDULED_TIME_RANGE_END => SNOWFLAKE.ALERT.SCHEDULED_TIME(),
            ERROR_ONLY => TRUE
        ))
        WHERE DATABASE_NAME = 'NZBANK_HOL'
    ))
    THEN
        BEGIN
            LET failed_tasks STRING := (
                SELECT LISTAGG(DISTINCT (SCHEMA_NAME || '.' || NAME), ', ')
                FROM TABLE(RESULT_SCAN(SNOWFLAKE.ALERT.GET_CONDITION_QUERY_UUID()))
            );
            CALL SYSTEM$SEND_SNOWFLAKE_NOTIFICATION(
                SNOWFLAKE.NOTIFICATION.TEXT_HTML(
                    'Tasks ' || :failed_tasks || ' failed in NZBANK_HOL since ' ||
                    (GREATEST(TIMEADD('day', -1, CURRENT_TIMESTAMP()), SNOWFLAKE.ALERT.LAST_SUCCESSFUL_SCHEDULED_TIME()))
                ),
                SNOWFLAKE.NOTIFICATION.EMAIL_INTEGRATION_CONFIG(
                    'NZBANK_EMAIL_NOTIFICATIONS',
                    'NZBANK dbt Pipeline Alert',
                    ARRAY_CONSTRUCT('<YOUR EMAIL HERE>')
                )
            );
        END;

ALTER ALERT NZBANK_HOL.PROD.NZBANK_DBT_ALERT RESUME;

-- Run once to confirm the alert fires correctly against current history
EXECUTE ALERT NZBANK_HOL.PROD.NZBANK_DBT_ALERT;
