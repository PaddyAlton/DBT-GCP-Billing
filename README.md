DBT-GCP-Billing
===============

Do you use Google Cloud Platform and BigQuery?

**If so, this template project is for you!**

Google Cloud Platform allows you to set up an export of your billing information. To do this, you need to navigate to [Billing](https://console.cloud.google.com/billing) and then select 'Billing Export' from the left-hand menu.

The Billing Export
------------------

There are three data tables you can export to BigQuery:

- Standard Usage Costs
- Detailed Usage Costs (similar to standard, but larger because costs are broken down to the 'resource' level)
- Pricing (details of what you can expect to be charged)

These tables show up in a dataset called `gcp_billing` in BigQuery. They are partitioned tables and are updated every day.

This template is a demonstration of how to normalise the first of these tables. However, it would be easy to modify to normalise detailed usage costs instead. It could also be extended to handle pricing data.

How DBT Helps
-------------

The exported cost table is highly denormalised, with nested fields and a structure that can be hard to understand at first:

- each record denotes a single billing record, with any associated credits (where multiple credits may be applied to a single record; the structure is nested)
- costs are _usually positive_
- some costs are zero (and have credits attached), or even negative (e.g. refunds)
- most credits are negative (money back), but not all
- some rows appear duplicated; the standard export doesn't contain resource-level data so it's possible for two line items to be indistinguishable (for this reason we can't construct a reliable surrogate key)

Nested data tables are typically not readily handled by business intelligence tools, and interpreting this table in particular requires a good deal of contextual information. For this reason it makes sense to use DBT to flatten this table, incorporating only those nested fields that are important for our purposes.

This project
------------

This project defines some DBT incremental models that

- load your GCP standard billing export into a partitioned table with relevant values extracted from structs and dates properly parsed
- unnests credits information and separates into new records; thus the cost field is given a simple interpretation of money out (or in, if negative)
- creates a flattened 'fact' table recording all costs of GCP with important associated information (less useful fields are dropped at this point)

Strictly speaking, this is more of an OBT model than a fact table, because it does not just contain measures and identifiers for dimension tables. Further normalisation into a star schema is beyond the scope of this template project.

Please note: this project contains a custom `generate_schema_name` macro, which will write models to different schemas depending on schemas defined in `dbt_project.yml` and whether the environment variable `$DBT
_EXEC_PROFILE` is set to `prod` or not. 

By default, a production run would create three datasets, `dbt_base`, `dbt_intm`, and `dbt_marts`, and the models would be appropriately separated between them.

If `$DBT_EXEC_PROFILE` is set to something other than `prod` (the default is `dev`) then the environment variable will be appended to the schema/dataset name.

Getting started
---------------

You will need to fill out `profiles.yml` appropriately and add appropriate service account credentials at `config/credentials.json`. This is to authorise connectivity with BigQuery.

I've included some boilerplate infrastructure. To make the most of this you will need to install [Docker](https://docs.docker.com/get-docker/) and [Taskfile](https://taskfile.dev/installation/) (for this purpose
 - i.e running one-off, interactive tasks rather than a persistent application - I prefer this to Docker Compose).

If you do this, you should be able to do:
- `task build_image` to build an image for the DBT project
- `task start` to run a shell inside that image (you can then execute `dbt run` commands interactively) with volume mounting keeping your models up to date
- `task build_docs` to build the DBT documentation site
- `task serve_docs` to serve the DBT documentation site (after building it!) on `localhost:8123`

Acknowledgements
----------------

I am indebted to my previous employer, [Apolitical Group Ltd](https://apolitical.co/), for giving permission to open-source this work.
