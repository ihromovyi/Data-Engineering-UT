{{ config(materialized='table') }}

SELECT DISTINCT
    member_casual AS user_key,
    member_casual
FROM {{ source('bronze', 'citibikenyc_trips') }}
WHERE member_casual IS NOT NULL