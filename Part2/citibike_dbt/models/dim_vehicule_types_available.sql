{{ config(materialized='table') }}

WITH status_stat AS (
    SELECT
        _loaded_at,
        jsonb_array_elements(stat_status) AS station
    FROM {{ source('bronze', 'citibikenyc_stations_status') }}
    ORDER BY _loaded_at DESC
    LIMIT 1
),

vehicles AS (
    SELECT
        _loaded_at,
        station ->> 'station_id' AS station_id,
        (TO_TIMESTAMP((station ->> 'last_reported')::bigint) AT TIME ZONE 'UTC')::timestamp AS reported_at,
        jsonb_array_elements(station -> 'vehicle_types_available') AS vehicle_avail
    FROM status_stat
    WHERE station -> 'vehicle_types_available' IS NOT NULL
)

SELECT
    ROW_NUMBER() OVER (ORDER BY (vehicle_avail ->> 'vehicle_type_id')::int) AS count_id,
    CASE 
        WHEN vehicle_avail ->> 'vehicle_type_id' = '1' THEN 'classic_bike'
        WHEN vehicle_avail ->> 'vehicle_type_id' = '2' THEN 'electric_bike'
    END AS rideable_type,
    (vehicle_avail ->> 'count')::int AS count
FROM vehicles
WHERE vehicle_avail ->> 'vehicle_type_id' IS NOT NULL