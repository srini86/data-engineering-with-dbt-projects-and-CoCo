# dbt Modelling Standards

## Model Config

### Materialization by Layer
- **Staging (`stg_`)**: `view` — lightweight, always fresh
- **Intermediate (`int_`)**: `ephemeral` or `view` — no need to persist intermediate logic
- **Marts (`fct_`, `dim_`)**: `table` for small/medium, `incremental` for large fact tables
- **Reporting/aggregates**: `table` with `on_schema_change = 'append_new_columns'`

Always set materialization explicitly in the model config block — do not rely on `dbt_project.yml` defaults alone:

```sql
{{ config(
    materialized='incremental',
    unique_key='order_key',
    on_schema_change='append_new_columns',
    merge_exclude_columns=['_loaded_at']
) }}
```

### Schema Change Handling
- All incremental models must specify `on_schema_change`:
  - Use `'append_new_columns'` (default choice) — adds new columns, ignores removed ones
  - Use `'sync_all_columns'` only when downstream consumers need exact schema parity
  - Never leave it unset — silent column drops are a production incident waiting to happen

### Tags
Use tags for **operational grouping only** — not as documentation or categorisation:
- `tag: 'daily'` / `tag: 'hourly'` — scheduling tier (used by task selectors)
- `tag: 'pii'` — flags models containing sensitive data for masking policies
- Do not tag by domain or team — use folder structure (`models/finance/`, `models/marketing/`) instead

## Incremental Models

### Required Config
Every incremental model must include:
- `unique_key` — the column(s) used for merge deduplication
- `on_schema_change` — how to handle column drift
- `merge_exclude_columns=['_loaded_at']` — preserve the original insert timestamp on updates

```sql
{{ config(
    materialized='incremental',
    unique_key='my_surrogate_key',
    on_schema_change='append_new_columns',
    merge_exclude_columns=['_loaded_at']
) }}
```

### Incremental Filter Logic
Use `{% if is_incremental() %}` to limit which source rows are processed on subsequent runs.

**Preferred: Ingestion-timestamp filter** (most efficient)
If the source table has a reliable ingestion/load timestamp column, filter on it:

```sql
{% if is_incremental() %}
    AND source._loaded_at >= (SELECT MAX(_updated_at) FROM {{ this }})
{% endif %}
```

This only scans rows that arrived since the last run — regardless of their business date.

**Fallback: Lookback-one-period filter** (safe default)
When no ingestion timestamp exists, look back one aggregation period from the most recent data in the target:

```sql
{% if is_incremental() %}
    AND oh.order_ts >= (SELECT DATEADD('month', -1, MAX(month)) FROM {{ this }})
{% endif %}
```

This re-processes the most recent period to catch late-arriving data. It is less efficient (re-scans one full period each run) but safe for sources without ingestion timestamps.

**When to use which:**
| Approach | Use when | Trade-off |
|----------|----------|-----------|
| Ingestion timestamp | Source has `_loaded_at` or similar column | Most efficient — only new rows scanned |
| Lookback 1 period | No ingestion timestamp, late-arriving data possible | Safe but reprocesses ~1 period per run |
| No lookback (strict append) | Source is immutable, data never arrives late | Most efficient but brittle — late data is lost |

### Idempotency
- Incremental models must produce the same result whether run once or multiple times — no duplicates, no missed rows
- The combination of `unique_key` + merge ensures this: re-processing a row updates it in place rather than duplicating it
- Always test by running the model twice in a row and confirming row counts are stable

## Surrogate Keys
- Always generate surrogate keys using `{{ dbt_utils.generate_surrogate_key(['col1', 'col2']) }}`
- Name the key column `<model_name>_key`
- The columns used in the surrogate key must be the grain of the model (one row per unique combination)

## Timestamps
- `_loaded_at`: when the row was first inserted — `{{ dbt.current_timestamp() }}`
- `_updated_at`: when the row was last refreshed — `{{ dbt.current_timestamp() }}`
- For incremental models, always add `merge_exclude_columns=['_loaded_at']` to config so `_loaded_at` is preserved on updates
- Without `merge_exclude_columns`, both columns will always be identical (defeating the purpose)

## Naming Conventions
- Staging models: `stg_<source>__<entity>`
- Intermediate: `int_<entity>_<verb>`

## Macros
- Use `{{ ref() }}` for all model references — never hardcode table names
- Use `{{ source() }}` for raw tables
- Prefer `{{ dbt_utils.star() }}` over `SELECT *`

## Testing
- Every primary key must have `not_null` + `unique` tests
- Every foreign key must have a `relationships` test

## SQL Style

### Import CTEs
Each upstream model is imported once at the top of the file using `select *`, making dependencies immediately visible:

```sql
with order_headers as (
    select * from {{ ref('stg_order_header') }}
),

order_details as (
    select * from {{ ref('stg_order_detail') }}
),
```

### Keywords and Formatting
- Use **lowercase SQL keywords** (`select`, `from`, `where`, `group by`) per the dbt style guide
- Use **explicit `inner join`** — never bare `JOIN` — making intent clear
- Use **descriptive CTE aliases** — full names like `order_headers`, `order_details` instead of abbreviations like `oh`, `od`, `m`

### Final CTE Pattern
All transformation logic lives in named CTEs. The model ends with `select * from final`:

```sql
-- import CTEs
with order_headers as ( ... ),
     order_details as ( ... ),

-- logical CTEs
enriched_orders as (
    select ...
    from order_headers
    inner join order_details on ...
),

final as (
    select ...
    from enriched_orders
)

-- final
select * from final
```

### Section Comments
Separate import, logical, and final CTEs with section comments for readability.
