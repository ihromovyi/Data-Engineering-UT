{{ config(materialized='table') }}

SELECT DISTINCT
    started_at::timestamp AS datetime_id,
    EXTRACT(YEAR FROM started_at::timestamp) AS year,
    EXTRACT(MONTH FROM started_at::timestamp) AS month,
    EXTRACT(DAY FROM started_at::timestamp) AS day,
    EXTRACT(HOUR FROM started_at::timestamp) AS hour,
    EXTRACT(MINUTE FROM started_at::timestamp) AS minute,
    EXTRACT(SECOND FROM started_at::timestamp) AS second
FROM {{ source('bronze', 'citibikenyc_trips') }}
WHERE started_at IS NOT NULL