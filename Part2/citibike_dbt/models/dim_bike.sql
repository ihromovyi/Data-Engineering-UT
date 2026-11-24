{{ config(materialized='table') }}

WITH latest_data AS (
    SELECT bikes_types
    FROM {{ source('bronze', 'citibikenyc_bikes_types') }}
    ORDER BY _loaded_at DESC
    LIMIT 1
),

bykes_types AS (
    SELECT jsonb_array_elements(bikes_types -> 'vehicle_types') AS vehicle
    FROM latest_data
)

SELECT DISTINCT
    (vehicle ->> 'vehicle_type_id')::int AS bike_id,
    CASE 
        WHEN vehicle ->> 'propulsion_type' = 'human' THEN 'classic_bike'
        WHEN vehicle ->> 'propulsion_type' = 'electric_assist' THEN 'electric_bike'
    END AS rideable_type,
    vehicle ->> 'form_factor' AS form_factor,
    vehicle ->> 'propulsion_type' AS propulsion_type,
    (vehicle ->> 'max_range_meters')::numeric AS max_range_meters
FROM bykes_types
WHERE vehicle ->> 'vehicle_type_id' IS NOT NULL