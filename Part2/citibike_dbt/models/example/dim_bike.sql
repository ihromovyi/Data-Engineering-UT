{{ config(materialized='table') }}

SELECT
    ROW_NUMBER() OVER (ORDER BY rideable_type) AS bike_key,
    rideable_type
FROM (
    SELECT DISTINCT rideable_type
    FROM bronze.citibikenyc_trips
) AS bikes