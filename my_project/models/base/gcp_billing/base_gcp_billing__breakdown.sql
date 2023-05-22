-- base_gcp_billing__breakdown.sql
-- incrementally-built partitioned GCP billing table,
-- with some flattening applied.

{{
  config(
    materialized = 'incremental',
    partition_by = {
      'field': 'usage_date',
      'data_type': 'date',
      'granularity': 'day'},
    incremental_strategy = 'insert_overwrite',
    on_schema_change = 'fail',
    tags=['incremental', 'daily']
  )
}}
/*
SOME DETAILS:

- costs can be positive, zero, or negative
- costs are associated with credits, which are typically (but not always!) negative
- any credits need to be added to their associated costs to get the total cost of a line item
- some line items appear to be duplicates, but in general this seems to be correct:
  -- the table isn't so granular that we can always distinguish costs exactly
  -- sometimes discount credits are applied to a series of separate, zero-cost rows
*/
    SELECT
        -- export details
        export_time,
        DATE(export_time) AS export_date,
        -- cost identification
        billing_account_id,
        service.id AS service_id,
        service.description AS service_description,
        sku.id AS sku_id,
        sku.description AS sku_description,
        cost_type,
        -- cost timing
        usage_start_time,
        usage_end_time,
        DATE(usage_start_time) AS usage_date,
        PARSE_DATE('%Y%m', invoice.month) AS invoice_month,
        -- cost location
        location.location AS location,
        location.country AS country,
        location.region AS region,
        location.zone AS zone,
        (SELECT value FROM UNNEST(labels) WHERE key='environment') AS environment,
        -- cost information
        cost,
        currency,
        currency_conversion_rate,
        -- usage information
        usage.amount AS usage_amount,
        usage.unit AS usage_unit,
        usage.amount_in_pricing_units AS usage_amount_in_pricing_units,
        usage.pricing_unit AS usage_pricing_unit,
        -- adjustment information
        adjustment_info.id AS adjustment_id,
        adjustment_info.description AS adjustment_description,
        adjustment_info.mode AS adjustment_mode,
        adjustment_info.type AS adjustment_type,
        -- nested details
        project,
        labels as resource_labels,
        system_labels,
        credits,
        tags,
      FROM
        {{ source('gcp_billing', 'billing_export') }}
{% if is_incremental() %}
     WHERE -- on incremental runs, overwrite last partition (in case incomplete) and add new partitions
           DATE(usage_start_time) >= DATE(_dbt_max_partition)
        OR DATE(export_time) >= DATE(_dbt_max_partition)
{% endif %}
