{{ config(materialized='table') }}

WITH latest_status AS (
    SELECT
        _loaded_at,
        stat_status
    FROM {{ source('bronze', 'citibikenyc_stations_status') }}
),

station_status AS (
    SELECT
        _loaded_at,
        jsonb_array_elements(stat_status) AS station
    FROM latest_status
),

all_station_status AS (
    SELECT
        _loaded_at,
        station,
        station ->> 'station_id' AS station_id,
        (TO_TIMESTAMP((station ->> 'last_reported')::bigint) AT TIME ZONE 'UTC')::timestamp AS reported_at,
        jsonb_array_elements(station -> 'vehicle_types_available') AS vehicle_avail
    FROM station_status
)

SELECT
    ROW_NUMBER() OVER (ORDER BY s._loaded_at, s.station_id) AS id,
    stat_info.station_id,
    (s.station ->> 'num_bikes_available')::int AS num_bikes_available,
    (s.station ->> 'num_bikes_disabled')::int AS num_bikes_disabled,
    (s.station ->> 'num_docks_available')::int AS num_docks_available,
    (s.station ->> 'num_docks_disabled')::int AS num_docks_disabled,
    (s.station ->> 'is_installed')::int AS is_installed,
    (s.station ->> 'is_renting')::int AS is_renting,
    (s.station ->> 'is_returning')::int AS is_returning,
    d.datetime_id,
    CASE 
        WHEN s.vehicle_avail ->> 'vehicle_type_id' = '1' THEN (s.vehicle_avail ->> 'count')::int
    END AS classic_bikes_available,
    CASE 
        WHEN s.vehicle_avail ->> 'vehicle_type_id' = '2' THEN (s.vehicle_avail ->> 'count')::int
    END AS electric_bikes_available

FROM all_station_status AS s

LEFT JOIN {{ ref('dim_datetime') }} AS d
    ON s.reported_at = d.datetime_id

LEFT JOIN {{ ref('dim_station') }} AS stat_info
    ON s.station_id = stat_info.station_id