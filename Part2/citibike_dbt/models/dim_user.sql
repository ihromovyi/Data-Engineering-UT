{{ config(materialized='table') }}

SELECT DISTINCT
    ROW_NUMBER() OVER (ORDER BY member_casual)::integer AS user_key,
    member_casual
FROM {{ source('bronze', 'citibikenyc_trips') }}
WHERE member_casual IS NOT NULL