-- intermediate_financials__gcp_billing.sql
-- flattens the base table by unwrapping credits associated with costs
-- onto their own set of (zero cost) rows (inspired by the Data Studio
-- GCP Template)

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

        -- first part of the query holds gross (pre-credit) cost information
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
        'gross' AS line_item_type,
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
        'GROSS_COST' AS cost_metric_type,
        'Gross cost' AS cost_metric_subtype,
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
        -- nested details
        project,
        resource_labels,
        system_labels,
        tags,      
      FROM
        {{ ref('base_gcp_billing__breakdown') }}
{% if is_incremental() %}
     WHERE -- on incremental runs, overwrite last partition (in case incomplete) and add new partitions
        usage_date >= DATE(_dbt_max_partition)
{% endif %}

 UNION ALL
        -- second part of the query holds credits information
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
        'credit' AS line_item_type,
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
        creds.type AS cost_metric_type,
        CONCAT('Credit: ', creds.name) AS cost_metric_subtype,
        creds.amount AS cost,
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
        -- nested details
        project,
        resource_labels,
        system_labels,
        tags,
      FROM
        {{ ref('base_gcp_billing__breakdown') }}
CROSS JOIN
        -- retrieve a duplicate row for every element of the 'credits' array
        -- for records where that array exists - assign credit amount to 'cost'
        UNNEST(credits) AS creds
{% if is_incremental() %}
     WHERE -- on incremental runs, overwrite last partition (in case incomplete) and add new partitions
        usage_date >= DATE(_dbt_max_partition)
{% endif %}
