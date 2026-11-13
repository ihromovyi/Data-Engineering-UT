{{ config(materialized='table') }}

SELECT DISTINCT
    started_at::timestamp AS datetime_key,
    EXTRACT(YEAR FROM started_at::timestamp) AS year,
    EXTRACT(MONTH FROM started_at::timestamp) AS month,
    EXTRACT(DAY FROM started_at::timestamp) AS day,
    EXTRACT(HOUR FROM started_at::timestamp) AS hour
FROM {{ source('bronze', 'citibikenyc_trips') }}