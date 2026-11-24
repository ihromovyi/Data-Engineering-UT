{{ config(materialized='table') }}

WITH station_status AS (
    SELECT
        _loaded_at,
        jsonb_array_elements(stat_status) AS station
    FROM {{ source('bronze', 'citibikenyc_stations_status') }}
),

all_station_status AS (
    SELECT
        _loaded_at,
        station ->> 'station_id' AS station_id,
        (TO_TIMESTAMP((station ->> 'last_reported')::bigint) AT TIME ZONE 'UTC')::timestamp AS reported_at,
        jsonb_array_elements(station -> 'vehicle_types_available') AS vehicle_avail
    FROM station_status
),

SELECT
    ROW_NUMBER() AS id,
    s.station_id,
    t.num_bikes_available,
    t.num_bikes_disabled,
    t.num_docks_available,
    t.num_docks_disabled,
    t.is_installed,
    t.is_renting,
    t.is_returning,
    d.datetime_id,
    CASE 
        WHEN s.vehicle_avail ->> 'vehicle_type_id' = '1' THEN s.count
    END AS classic_bikes_available,
    CASE 
        WHEN s.vehicle_avail ->> 'vehicle_type_id' = '2' THEN s.count
    END AS electric_bikes_available,
    

FROM all_station_status AS s

LEFT JOIN {{ ref('dim_datetime') }} AS d
    ON (TO_TIMESTAMP(s.last_reported::bigint) AT TIME ZONE 'UTC')::timestamp = d.datetime_id

LEFT JOIN {{ ref('dim_station') }} AS stat_info
    ON s.