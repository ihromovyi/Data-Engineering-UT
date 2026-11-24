{{ config(materialized='table') }}

WITH distinct_users AS (
    SELECT DISTINCT member_casual
    FROM {{ source('bronze', 'citibikenyc_trips') }}
    WHERE member_casual IS NOT NULL
)

SELECT
    ROW_NUMBER() OVER (ORDER BY member_casual)::integer AS user_id,
    member_casual
FROM distinct_users