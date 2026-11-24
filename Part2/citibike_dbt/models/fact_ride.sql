{{ config(materialized='table') }}

SELECT
    ROW_NUMBER() OVER (ORDER BY t.ride_id) AS id,
    t.ride_id AS ride_id,
    b.bike_id AS rideable_type_id,
    u.user_id AS member_casual_id,
    start_station.station_id AS start_station_id,
    end_station.station_id AS end_station_id,
    d_start.datetime_id AS started_at_id,
    d_end.datetime_id AS end_at_id,
    t.start_lat AS start_lat,
    t.start_lng AS start_lng,
    t.end_lat AS end_lat,
    t.end_lng AS end_lng

FROM {{ source('bronze', 'citibikenyc_trips') }} AS t

LEFT JOIN {{ ref('dim_bike') }} AS b
    ON t.rideable_type = b.rideable_type

LEFT JOIN {{ ref('dim_user') }} AS u
    ON t.member_casual = u.member_casual

LEFT JOIN {{ ref('dim_station') }} AS start_station
    ON t.start_station_id = start_station.short_name

LEFT JOIN {{ ref('dim_station') }} AS end_station
    ON t.end_station_id = end_station.short_name

LEFT JOIN {{ ref('dim_datetime') }} AS d_start
    ON t.started_at::timestamp = d_start.datetime_id

LEFT JOIN {{ ref('dim_datetime') }} AS d_end
    ON t.ended_at::timestamp = d_end.datetime_id