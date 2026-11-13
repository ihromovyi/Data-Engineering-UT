
{{ config(materialized='table') }}

WITH latest_data AS (
    SELECT stat_informations
    FROM {{ source('bronze', 'citibikenyc_stations_informations') }}
    ORDER BY _loaded_at DESC
    LIMIT 1
),

stations AS (
    SELECT jsonb_array_elements(stat_informations) AS station
    FROM latest_data
)

SELECT
    station ->> 'station_id' AS station_id,
    station ->> 'name' AS station_name,
    (station ->> 'lat')::double precision AS latitude,
    (station ->> 'lon')::double precision AS longitude,
    (station ->> 'capacity')::integer AS capacity,
    (station ->> 'is_charging')::boolean AS is_charging
FROM stations
