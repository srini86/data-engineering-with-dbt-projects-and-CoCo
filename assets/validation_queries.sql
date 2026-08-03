-- ============================================================================
-- validation_queries.sql
-- Validation checks referenced across the lab's modules.
-- Paste sections into a Workspace SQL file as you go, or ask CoCo to run
-- the equivalent check for you.
-- ============================================================================

-- Module 01: confirm source data loaded
USE ROLE ACCOUNTADMIN;
USE WAREHOUSE tasty_bytes_dbt_wh;

SHOW TABLES IN SCHEMA tasty_bytes_dbt_db.RAW;

SELECT COUNT(*) AS row_count FROM tasty_bytes_dbt_db.RAW.ORDER_HEADER;

-- ----------------------------------------------------------------------
-- Module 02: validate the generated model (adjust name if CoCo named it
-- differently -- check the model file it created for the actual name)
-- ----------------------------------------------------------------------
SELECT
    TRUCK_ID,
    TRUCK_BRAND_NAME,
    SALES_WEEK,
    TOTAL_REVENUE,
    TOTAL_ORDERS,
    AVG_ORDER_VALUE,
    PROFIT_MARGIN
FROM tasty_bytes_dbt_db.DEV.WEEKLY_TRUCK_PERFORMANCE
ORDER BY TOTAL_REVENUE DESC
LIMIT 10;

-- Null / row-count sanity check on the required columns
SELECT
    COUNT(*) AS total_rows,
    COUNT(TRUCK_ID) AS non_null_truck_id
FROM tasty_bytes_dbt_db.DEV.WEEKLY_TRUCK_PERFORMANCE;

-- ----------------------------------------------------------------------
-- Module 03: validate deployment and Task execution
-- ----------------------------------------------------------------------
SHOW DBT PROJECTS IN SCHEMA tasty_bytes_dbt_db.PROD;

SELECT *
FROM TABLE(tasty_bytes_dbt_db.INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -1, CURRENT_TIMESTAMP())
))
WHERE NAME = 'TB_DBT_BUILD_TASK'
ORDER BY SCHEDULED_TIME DESC;

-- Confirm the alert is active
SHOW ALERTS LIKE 'tb_dbt%' IN SCHEMA tasty_bytes_dbt_db.PROD;
