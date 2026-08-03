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
USE WAREHOUSE tasty_bytes_dbt_wh;

-- ----------------------------------------------------------------------
-- Task: Build (run + test) the dbt project daily at 06:00 UTC
-- `build` runs models and tests in DAG order, failing early if any test fails.
-- ----------------------------------------------------------------------
ALTER TASK IF EXISTS tasty_bytes_dbt_db.prod.tb_dbt_build_task SUSPEND;

CREATE OR ALTER TASK tasty_bytes_dbt_db.prod.tb_dbt_build_task
    WAREHOUSE = tasty_bytes_dbt_wh
    SCHEDULE = 'USING CRON 0 6 * * * UTC'
AS
    EXECUTE DBT PROJECT tasty_bytes_dbt_db.prod.tasty_bytes_dbt_project
        ARGS = 'build --target prod';

ALTER TASK tasty_bytes_dbt_db.prod.tb_dbt_build_task RESUME;

-- Run once immediately to confirm the task works
EXECUTE TASK tasty_bytes_dbt_db.prod.tb_dbt_build_task;

-- ----------------------------------------------------------------------
-- Notification Integration: required for the alert to send emails.
-- Replace <YOUR EMAIL HERE> with your verified Snowsight email address.
-- ----------------------------------------------------------------------
CREATE NOTIFICATION INTEGRATION IF NOT EXISTS tb_dbt_email_notifications
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('<YOUR EMAIL HERE>');

-- ----------------------------------------------------------------------
-- Alert: notify on task failure.
-- NOTE: verify your email in Snowsight first (user icon > Profile > email),
-- and replace <YOUR EMAIL HERE> below before running.
-- ----------------------------------------------------------------------
CREATE OR REPLACE ALERT tasty_bytes_dbt_db.prod.tb_dbt_alert
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

ALTER ALERT tasty_bytes_dbt_db.prod.tb_dbt_alert RESUME;

-- Run once to confirm the alert fires correctly against current history
EXECUTE ALERT tasty_bytes_dbt_db.prod.tb_dbt_alert;

-- Optional check for alert task history
SELECT *
FROM TABLE(tasty_bytes_dbt_db.INFORMATION_SCHEMA.ALERT_HISTORY(
    ALERT_NAME => 'TB_DBT_ALERT',
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
ORDER BY SCHEDULED_TIME DESC;
