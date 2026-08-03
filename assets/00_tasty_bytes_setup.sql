-- ============================================================================
-- 00_tasty_bytes_setup.sql
-- Environment setup for the Tasty Bytes dbt project used in this lab.
--
-- Based on the official Snowflake tutorial setup script:
-- https://github.com/Snowflake-Labs/getting-started-with-dbt-on-snowflake/blob/main/tasty_bytes_dbt_demo/setup/tasty_bytes_setup.sql
--
-- HOW TO RUN: paste this whole file into a new SQL File in a Snowsight
-- Workspace (Projects > Workspaces > + > SQL File), then click "Run All".
-- No terminal, no CLI needed.
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ----------------------------------------------------------------------
-- STEP 1: Warehouse
-- XL for the bulk load, then scaled back to XS for the rest of the lab.
-- ----------------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS NZBANK_WH
    WAREHOUSE_SIZE = 'XLARGE'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE NZBANK_WH;

-- ----------------------------------------------------------------------
-- STEP 2: Database and schemas
-- RAW holds the Tasty Bytes source data. DEV/PROD are where your dbt
-- project materializes models. INTEGRATIONS stores GitHub-related objects.
-- ----------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS NZBANK_HOL;
CREATE SCHEMA IF NOT EXISTS NZBANK_HOL.raw;
CREATE SCHEMA IF NOT EXISTS NZBANK_HOL.dev;
CREATE SCHEMA IF NOT EXISTS NZBANK_HOL.prod;
CREATE SCHEMA IF NOT EXISTS NZBANK_HOL.integrations;

-- ----------------------------------------------------------------------
-- STEP 3: Logging, tracing, and metrics
-- Lets you see dbt project run traces in Snowsight's Traces & Logs page
-- in Module 03.
-- ----------------------------------------------------------------------
ALTER SCHEMA NZBANK_HOL.dev SET LOG_LEVEL = 'INFO';
ALTER SCHEMA NZBANK_HOL.dev SET TRACE_LEVEL = 'ALWAYS';
ALTER SCHEMA NZBANK_HOL.dev SET METRIC_LEVEL = 'ALL';

ALTER SCHEMA NZBANK_HOL.prod SET LOG_LEVEL = 'INFO';
ALTER SCHEMA NZBANK_HOL.prod SET TRACE_LEVEL = 'ALWAYS';
ALTER SCHEMA NZBANK_HOL.prod SET METRIC_LEVEL = 'ALL';

-- ----------------------------------------------------------------------
-- STEP 4: External Access Integration for dbt deps
-- dbt deps needs to reach hub.getdbt.com and codeload.github.com to
-- download packages (e.g. dbt_utils). This creates the network rule
-- and EAI so participants don't have to do it manually in the lab.
-- ----------------------------------------------------------------------
CREATE OR REPLACE NETWORK RULE NZBANK_HOL.integrations.dbt_deps_network_rule
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = ('hub.getdbt.com', 'codeload.github.com', 'github.com', 'raw.githubusercontent.com');

CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION DBT_DEPS_EAI
    ALLOWED_NETWORK_RULES = (NZBANK_HOL.integrations.dbt_deps_network_rule)
    ENABLED = TRUE;

-- ----------------------------------------------------------------------
-- STEP 5: Source data -- Tasty Bytes foundational data model
-- Creates the raw zone tables and loads them from Snowflake's public
-- quickstarts S3 bucket. No credentials needed -- this bucket is public.
-- ----------------------------------------------------------------------

CREATE OR REPLACE FILE FORMAT NZBANK_HOL.public.csv_ff
    TYPE = 'csv';

CREATE OR REPLACE STAGE NZBANK_HOL.public.s3load
    COMMENT = 'Quickstarts S3 Stage Connection'
    URL = 's3://sfquickstarts/frostbyte_tastybytes/'
    FILE_FORMAT = NZBANK_HOL.public.csv_ff;

CREATE OR REPLACE TABLE NZBANK_HOL.raw.country (
    country_id NUMBER(18,0), country VARCHAR, iso_currency VARCHAR(3),
    iso_country VARCHAR(2), city_id NUMBER(19,0), city VARCHAR, city_population VARCHAR
);

CREATE OR REPLACE TABLE NZBANK_HOL.raw.franchise (
    franchise_id NUMBER(38,0), first_name VARCHAR, last_name VARCHAR,
    city VARCHAR, country VARCHAR, e_mail VARCHAR, phone_number VARCHAR
);

CREATE OR REPLACE TABLE NZBANK_HOL.raw.location (
    location_id NUMBER(19,0), placekey VARCHAR, location VARCHAR, city VARCHAR,
    region VARCHAR, iso_country_code VARCHAR, country VARCHAR
);

CREATE OR REPLACE TABLE NZBANK_HOL.raw.menu (
    menu_id NUMBER(19,0), menu_type_id NUMBER(38,0), menu_type VARCHAR,
    truck_brand_name VARCHAR, menu_item_id NUMBER(38,0), menu_item_name VARCHAR,
    item_category VARCHAR, item_subcategory VARCHAR, cost_of_goods_usd NUMBER(38,4),
    sale_price_usd NUMBER(38,4), menu_item_health_metrics_obj VARIANT
);

CREATE OR REPLACE TABLE NZBANK_HOL.raw.truck (
    truck_id NUMBER(38,0), menu_type_id NUMBER(38,0), primary_city VARCHAR,
    region VARCHAR, iso_region VARCHAR, country VARCHAR, iso_country_code VARCHAR,
    franchise_flag NUMBER(38,0), year NUMBER(38,0), make VARCHAR, model VARCHAR,
    ev_flag NUMBER(38,0), franchise_id NUMBER(38,0), truck_opening_date DATE
);

CREATE OR REPLACE TABLE NZBANK_HOL.raw.order_header (
    order_id NUMBER(38,0), truck_id NUMBER(38,0), location_id FLOAT,
    customer_id NUMBER(38,0), discount_id VARCHAR, shift_id NUMBER(38,0),
    shift_start_time TIME(9), shift_end_time TIME(9), order_channel VARCHAR,
    order_ts TIMESTAMP_NTZ(9), served_ts VARCHAR, order_currency VARCHAR(3),
    order_amount NUMBER(38,4), order_tax_amount VARCHAR, order_discount_amount VARCHAR,
    order_total NUMBER(38,4)
);

CREATE OR REPLACE TABLE NZBANK_HOL.raw.order_detail (
    order_detail_id NUMBER(38,0), order_id NUMBER(38,0), menu_item_id NUMBER(38,0),
    discount_id VARCHAR, line_number NUMBER(38,0), quantity NUMBER(5,0),
    unit_price NUMBER(38,4), price NUMBER(38,4), order_item_discount_amount VARCHAR
);

CREATE OR REPLACE TABLE NZBANK_HOL.raw.customer_loyalty (
    customer_id NUMBER(38,0), first_name VARCHAR, last_name VARCHAR, city VARCHAR,
    country VARCHAR, postal_code VARCHAR, preferred_language VARCHAR, gender VARCHAR,
    favourite_brand VARCHAR, marital_status VARCHAR, children_count VARCHAR,
    sign_up_date DATE, birthday_date DATE, e_mail VARCHAR, phone_number VARCHAR
);

COPY INTO NZBANK_HOL.raw.country      FROM @NZBANK_HOL.public.s3load/raw_pos/country/;
COPY INTO NZBANK_HOL.raw.franchise    FROM @NZBANK_HOL.public.s3load/raw_pos/franchise/;
COPY INTO NZBANK_HOL.raw.location     FROM @NZBANK_HOL.public.s3load/raw_pos/location/;
COPY INTO NZBANK_HOL.raw.menu         FROM @NZBANK_HOL.public.s3load/raw_pos/menu/;
COPY INTO NZBANK_HOL.raw.truck        FROM @NZBANK_HOL.public.s3load/raw_pos/truck/;
COPY INTO NZBANK_HOL.raw.customer_loyalty FROM @NZBANK_HOL.public.s3load/raw_customer/customer_loyalty/;
COPY INTO NZBANK_HOL.raw.order_header FROM @NZBANK_HOL.public.s3load/raw_pos/order_header/;
COPY INTO NZBANK_HOL.raw.order_detail FROM @NZBANK_HOL.public.s3load/raw_pos/order_detail/;

SELECT 'NZBANK_HOL setup is complete' AS note;
