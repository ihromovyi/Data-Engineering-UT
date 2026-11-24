{{ config(materialized='table') }}

WITH latest_data AS (
    SELECT bikes_types
    FROM {{ source('bronze', 'citibikenyc_bikes_types') }}
    ORDER BY _loaded_at DESC
    LIMIT 1
),

stations AS (
    SELECT jsonb_array_elements(bikes_types) AS station
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
FROM extracted_vehicles
WHERE vehicle ->> 'vehicle_type_id' IS NOT NULL
