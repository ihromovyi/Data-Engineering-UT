-- SIMPLE POSTGRESQL QUERIES FOR YOUR STAR SCHEMA.
-- Tables: Fact_ride, Dim_Station, Dim_Bike, Dim_User, Dim_DateTime.
-- Unquoted SQL names are case-insensitive in PostgreSQL. If tables were created
-- with quoted mixed-case names, quote them consistently, e.g. "Fact_ride".
-- Assumptions: unique rides; valid foreign keys; NYC local calendar values.
-- Report month: September 2026. Change year/month in the helper and Q5/Q6.
-- Run everything in one session. Source tables are not modified.
-- Dim_Station is type 2: join using its id referenced by the fact,
-- NOT short_name and NOT is_current = true, for historical station attributes.
-- Capacity queries return one row per station VERSION if attributes changed.
-- valid_from/valid_to must have been applied correctly during fact loading.
-- Historical capacity is only known from snapshots actually collected.
-- Dim_DateTime has no minutes/seconds, so exact trip duration is unavailable.

-- ONE HELPER: one row per departure or arrival.
CREATE OR REPLACE TEMP VIEW movements AS
SELECT f.start_station_key AS station_key,
       MAKE_DATE(d.year, d.month, d.day) AS movement_date,
       d.hour, 'departure' AS direction, f.rideable_type_key
FROM Fact_ride f
JOIN Dim_DateTime d ON f.started_at_key = d.id
WHERE d.year = 2026 AND d.month = 9
UNION ALL
SELECT f.end_station_key, MAKE_DATE(d.year, d.month, d.day),
       d.hour, 'arrival', f.rideable_type_key
FROM Fact_ride f
JOIN Dim_DateTime d ON f.ended_at_key = d.id
WHERE d.year = 2026 AND d.month = 9;

-- Q1. Which stations have the highest departure-to-capacity ratio on days 1-5?
SELECT s.id, s.name, s.Capacity, COUNT(*) / s.Capacity AS turnover
FROM Fact_ride f
JOIN Dim_Station s
ON f.start_station_key = s.id AND s.is_current = TRUE
JOIN Dim_DateTime d
ON f.started_at_key = d.id
WHERE d.day BETWEEN 1 AND 5
GROUP BY s.id, s.name, s.Capacity
ORDER BY COUNT(*) * 1.0 / s.Capacity DESC;

-- Q2. How does activity vary by weekday/weekend and hour?
SELECT s.name,
       CASE WHEN EXTRACT(ISODOW FROM m.movement_date) >= 6
            THEN 'weekend' ELSE 'weekday' END AS day_type,
       m.hour, COUNT(*) AS movements
FROM movements m
JOIN Dim_Station s ON m.station_key = s.id
GROUP BY s.id, s.name, day_type, m.hour
ORDER BY s.name, day_type, m.hour;

-- Q3. Which stations show morning depletion or evening accumulation?
-- Q3a. Morning: your original query 1, unchanged.
SELECT s.id, s.name
FROM Fact_ride f

JOIN Dim_Station s
ON (f.start_station_key = s.id OR f.end_station_key = s.id) AND s.is_current = TRUE

JOIN Dim_DateTime d_start
ON f.started_at_key = d_start.id

JOIN Dim_DateTime d_end
ON f.ended_at_key = d_end.id

WHERE f.start_station_key <> f.end_station_key AND ((f.start_station_key=s.id AND d_start.hour BETWEEN 7 AND 9) OR (f.end_station_key=s.id AND d_end.hour BETWEEN 7 AND 9))

GROUP BY s.id, s.name
HAVING COUNT(CASE WHEN f.end_station_key = s.id THEN 1 END) - COUNT(CASE WHEN f.start_station_key = s.id THEN 1 END) < 0
ORDER BY COUNT(CASE WHEN f.end_station_key = s.id THEN 1 END) - COUNT(CASE WHEN f.start_station_key = s.id THEN 1 END) ASC
LIMIT 10;

-- Q3b. This query uses calendar days 1-5 and a net-flow threshold; it does not measure occupancy.
SELECT s.id, s.name, s.Capacity
FROM Fact_ride f
JOIN Dim_Station s
ON (f.start_station_key = s.id OR f.end_station_key = s.id)
JOIN Dim_DateTime d_start
ON f.started_at_key = d_start.id
JOIN Dim_DateTime d_end
ON f.ended_at_key = d_end.id

WHERE f.start_station_key <> f.end_station_key
 AND ((f.start_station_key = s.id AND d_start.day BETWEEN 1 AND 5 AND d_start.hour BETWEEN 17 AND 18)
   OR (f.end_station_key = s.id AND d_end.day BETWEEN 1 AND 5 AND d_end.hour BETWEEN 17 AND 18))
GROUP BY s.id, s.name, s.Capacity

HAVING (COUNT(CASE WHEN f.end_station_key = s.id THEN 1 END) - COUNT(CASE WHEN f.start_station_key = s.id THEN 1 END)) > 0.9 * s.Capacity

ORDER BY COUNT(CASE WHEN f.end_station_key = s.id THEN 1 END) - COUNT(CASE WHEN f.start_station_key = s.id THEN 1 END) DESC;

-- Q4. How do bike types differ in average departure intensity and net-outflow share?
SELECT rideable_type,
      AVG(turnover) AS avg_turnover,
      100 * COUNT(CASE WHEN flux < 0 THEN 1 END) / COUNT(*) AS deficit
FROM (
 SELECT s.id, s.Capacity, b.rideable_type,
        COUNT(CASE WHEN f.start_station_key = s.id THEN 1 END) * 1.0 / NULLIF(s.Capacity, 0) AS turnover,
        COUNT(CASE WHEN f.end_station_key = s.id THEN 1 END)
      - COUNT(CASE WHEN f.start_station_key = s.id THEN 1 END) AS flux
 FROM Fact_ride f
 JOIN Dim_Station s
 ON (f.start_station_key = s.id OR f.end_station_key = s.id) AND s.is_current = TRUE
 JOIN Dim_Bike b
 ON f.rideable_type_key = b.id
 GROUP BY s.id, s.Capacity, b.rideable_type
) t
GROUP BY rideable_type;

-- Q5. Which 60 directional origin-destination pairs have the most trips?
SELECT s1.name, s2.name, COUNT(*)
FROM Fact_ride f
JOIN Dim_Station s1
ON f.start_station_key = s1.id AND s1.is_current = TRUE
JOIN Dim_Station s2
ON f.end_station_key = s2.id AND s2.is_current = TRUE
GROUP BY s1.name, s2.name
ORDER BY COUNT(*) DESC
LIMIT 60;

-- Q6. How do member/casual riders differ in station choice and timing?
SELECT s.name, u.member_casual,
       EXTRACT(ISODOW FROM MAKE_DATE(d.year, d.month, d.day)) AS weekday_number,
       d.hour, COUNT(*) AS trips
FROM Fact_ride f
JOIN Dim_Station s ON f.start_station_key = s.id
JOIN Dim_User u ON f.member_casual_key = u.id
JOIN Dim_DateTime d ON f.started_at_key = d.id
WHERE d.year = 2026 AND d.month = 9
GROUP BY s.id, s.name, u.member_casual, weekday_number, d.hour
ORDER BY trips DESC;

-- Q7a. How does station activity change by day?
SELECT s.name, m.movement_date, COUNT(*) AS movements
FROM movements m
JOIN Dim_Station s ON m.station_key = s.id
GROUP BY s.id, s.name, m.movement_date
ORDER BY s.name, m.movement_date;

-- Q7b. How does activity change by week? Weeks start Monday.
SELECT s.name, DATE_TRUNC('week', m.movement_date)::date AS week_start,
       COUNT(*) AS movements
FROM movements m
JOIN Dim_Station s ON m.station_key = s.id
GROUP BY s.id, s.name, week_start
ORDER BY s.name, week_start;

-- Q8. Which stations warrant investigation for capacity/rebalancing changes?
SELECT s.name, s.capacity, COUNT(*) AS movements,
       COUNT(*) * 1.0 / NULLIF(s.capacity, 0) AS movements_per_dock,
       COUNT(*) FILTER (WHERE m.direction = 'arrival')
         - COUNT(*) FILTER (WHERE m.direction = 'departure') AS net_flow
FROM movements m
JOIN Dim_Station s ON m.station_key = s.id
GROUP BY s.id, s.name, s.capacity
ORDER BY movements_per_dock DESC NULLS LAST
LIMIT 20;

-- Q9. What share occurs at the busiest 10% of observed physical stations?
WITH station_totals AS (
    SELECT s.short_name, COUNT(*) AS movements
    FROM movements m
    JOIN Dim_Station s ON m.station_key = s.id
    GROUP BY s.short_name
), top_stations AS (
    SELECT *
    FROM station_totals
    ORDER BY movements DESC, short_name
    LIMIT (SELECT CEIL(COUNT(*) * 0.10)::integer FROM station_totals)
)
SELECT SUM(movements) * 100.0
       / NULLIF((SELECT SUM(movements) FROM station_totals), 0)
       AS top_10_percent_activity_share
FROM top_stations;

-- Q10. Which stations have steady activity versus large spikes?
WITH daily AS (
    SELECT s.short_name, m.movement_date,
           CASE WHEN EXTRACT(ISODOW FROM m.movement_date) >= 6
                THEN 'weekend' ELSE 'weekday' END AS day_type,
           COUNT(*) AS movements
    FROM movements m
    JOIN Dim_Station s ON m.station_key = s.id
    GROUP BY s.short_name, m.movement_date, day_type
)
SELECT short_name, day_type, COUNT(*) AS active_days,
       AVG(movements) AS avg_active_day_movements,
       MAX(movements) AS busiest_day_movements,
       STDDEV_POP(movements) AS daily_variation,
       MAX(movements) * 1.0 / NULLIF(AVG(movements), 0) AS peak_to_average
FROM daily
GROUP BY short_name, day_type
ORDER BY avg_active_day_movements DESC;
