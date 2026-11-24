{{ config(materialized='table') }}

WITH all_timestamps AS (
    SELECT started_at::timestamp AS dt FROM {{ source('bronze', 'citibikenyc_trips') }} WHERE started_at IS NOT NULL
    UNION
    SELECT ended_at::timestamp AS dt FROM {{ source('bronze', 'citibikenyc_trips') }} WHERE ended_at IS NOT NULL
    UNION
    SELECT (TO_TIMESTAMP((jsonb_array_elements(stat_status) ->> 'last_reported')::bigint) AT TIME ZONE 'UTC')::timestamp AS dt
    FROM {{ source('bronze', 'citibikenyc_stations_status') }}
)

SELECT DISTINCT
    dt AS datetime_id,
    EXTRACT(YEAR FROM dt) AS year,
    EXTRACT(MONTH FROM dt) AS month,
    EXTRACT(DAY FROM dt) AS day,
    EXTRACT(HOUR FROM dt) AS hour,
    EXTRACT(MINUTE FROM dt) AS minute,
    EXTRACT(SECOND FROM dt) AS second
FROM all_timestamps
WHERE dt IS NOT NULL