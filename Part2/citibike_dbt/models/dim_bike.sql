{{ config(materialized='table') }}

SELECT DISTINCT
    rideable_type AS bike_key,
    rideable_type
FROM {{ source('bronze', 'citibikenyc_trips') }}
WHERE rideable_type IS NOT NULL