-- marts_opex__gcp_billing.sql
-- Fact table of individual costs and credits provided by GCP

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

    SELECT
        -- export details
        export_time,
        export_date,
        -- cost identification
        billing_account_id,
        service_id,
        service_description,
        sku_id,
        sku_description,
        cost_type,
        line_item_type,
        -- cost timing
        usage_start_time,
        usage_end_time,
        usage_date,
        invoice_month,
        -- cost location
        location,
        country,
        region,
        zone,
        environment,
        -- cost information
        cost_metric_type,
        cost,
        currency,
        currency_conversion_rate,
        -- usage information
        usage_amount,
        usage_unit,
        usage_amount_in_pricing_units,
        usage_pricing_unit,
        -- adjustment information
        adjustment_id,
        adjustment_description,
        adjustment_mode,
        adjustment_type,
        -- nested details not included in marts models
        -- (e.g. over 70 different keys for 'label' that
        -- could be mapped to new columns)
      FROM
        {{ ref('intermediate_financials__gcp_billing') }}
{% if is_incremental() %}
     WHERE
        -- on incremental runs:
        -- overwrite last partition (in case incomplete) and add new partitions
        usage_date >= DATE(_dbt_max_partition)
{% endif %}
