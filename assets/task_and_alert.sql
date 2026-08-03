-- ============================================================================
-- task_and_alert.sql
-- Reference SQL for Module 03 (Deploy and Operate).
--
-- In the lab you create the schedule via the "Create Schedule" button on the
-- dbt project's Project Details page in Snowsight -- this file is the SQL
-- that button generates, kept here for reference and for the CI/CD mapping
-- discussion (this is exactly what your AWS CodePipeline step would run).
-- Adapted from https://github.com/Snowflake-Labs/getting-started-with-dbt-on-snowflake
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE NZBANK_WH;

-- ----------------------------------------------------------------------
-- Task: Build (run + test) the dbt project daily at 06:00 UTC
-- `build` runs models and tests in DAG order, failing early if any test fails.
-- ----------------------------------------------------------------------
ALTER TASK IF EXISTS NZBANK_HOL.prod.NZBANK_DBT_BUILD_TASK SUSPEND;

CREATE OR ALTER TASK NZBANK_HOL.prod.NZBANK_DBT_BUILD_TASK
    WAREHOUSE = NZBANK_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'
AS
    EXECUTE DBT PROJECT NZBANK_HOL.prod.NZBANK_DBT_PROJECT
        ARGS = 'build --target prod';

ALTER TASK NZBANK_HOL.prod.NZBANK_DBT_BUILD_TASK RESUME;

-- Run once immediately to confirm the task works
EXECUTE TASK NZBANK_HOL.prod.NZBANK_DBT_BUILD_TASK;

-- ----------------------------------------------------------------------
-- Notification Integration: required for the alert to send emails.
-- Replace <YOUR EMAIL HERE> with your verified Snowsight email address.
-- ----------------------------------------------------------------------
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS NZBANK_EMAIL_NOTIFICATIONS
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('<YOUR EMAIL HERE>');

-- ----------------------------------------------------------------------
-- Alert: notify on task failure.
-- NOTE: verify your email in Snowsight first (user icon > Profile > email),
-- and replace <YOUR EMAIL HERE> below before running.
-- ----------------------------------------------------------------------
CREATE OR REPLACE ALERT NZBANK_HOL.prod.NZBANK_DBT_ALERT
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
        WHERE DATABASE_NAME = 'TASTY_BYTES_DBT_DB'
    ))
    THEN
        BEGIN
            LET failed_tasks STRING := (
                SELECT LISTAGG(DISTINCT (SCHEMA_NAME || '.' || NAME), ', ')
                FROM TABLE(RESULT_SCAN(SNOWFLAKE.ALERT.GET_CONDITION_QUERY_UUID()))
            );
            CALL SYSTEM$SEND_SNOWFLAKE_NOTIFICATION(
                SNOWFLAKE.NOTIFICATION.TEXT_HTML(
                    'Tasks ' || :failed_tasks || ' failed in TASTY_BYTES_DBT_DB since ' ||
                    (GREATEST(TIMEADD('day', -1, CURRENT_TIMESTAMP()), SNOWFLAKE.ALERT.LAST_SUCCESSFUL_SCHEDULED_TIME()))
                ),
                SNOWFLAKE.NOTIFICATION.EMAIL_INTEGRATION_CONFIG(
                    'TB_DBT_EMAIL_NOTIFICATIONS',
                    'dbt Pipeline Alert',
                    ARRAY_CONSTRUCT('<YOUR EMAIL HERE>')
                )
            );
        END;

ALTER ALERT NZBANK_HOL.prod.NZBANK_DBT_ALERT RESUME;

-- Run once to confirm the alert fires correctly against current history
EXECUTE ALERT NZBANK_HOL.prod.NZBANK_DBT_ALERT;

-- Optional check for alert task history
SELECT *
FROM TABLE(NZBANK_HOL.INFORMATION_SCHEMA.ALERT_HISTORY(
    ALERT_NAME => 'TB_DBT_ALERT',
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
ORDER BY SCHEDULED_TIME DESC;
