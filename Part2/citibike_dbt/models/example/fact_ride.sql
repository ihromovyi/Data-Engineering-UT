{{ config(materialized='table') }}

SELECT
    t.ride_id,
    b.bike_key,
    u.user_key,
    d.datetime_key,
    t.start_station_id,
    t.end_station_id,
    start_station.station_name AS start_station_name,
    end_station.station_name AS end_station_name,
    EXTRACT(EPOCH FROM (
        t.ended_at::timestamp - t.started_at::timestamp
    )) / 60 AS duration_minutes

FROM {{ source('bronze', 'citibikenyc_trips') }} AS t

LEFT JOIN {{ ref('dim_bike') }} AS b
    ON t.rideable_type = b.rideable_type

LEFT JOIN {{ ref('dim_user') }} AS u
    ON t.member_casual = u.member_casual

LEFT JOIN {{ ref('dim_datetime') }} AS d
    ON t.started_at::timestamp = d.datetime_key

LEFT JOIN {{ ref('dim_station') }} AS start_station
    ON t.start_station_id = start_station.station_id

LEFT JOIN {{ ref('dim_station') }} AS end_station
    ON t.end_station_id = end_station.station_id