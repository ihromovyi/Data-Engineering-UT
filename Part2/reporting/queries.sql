-- Citi Bike: six refined business questions from the report. READ ONLY.
-- Run in pgAdmin Query Tool on bikes_db after ingestion and dbt complete.
-- Dates select October 2026; the recorded load covers only 1-15 October.
-- Change both month boundaries for another reporting period.

-- BQ1: Departures per dock
SELECT s.station_name,s.capacity,COUNT(*) AS departures,
ROUND(COUNT(*)*1.0/s.capacity,2) AS departures_per_dock
FROM gold.fact_ride f JOIN gold.dim_station s ON f.start_station_id=s.station_id
WHERE f.started_at_id >= TIMESTAMP '2026-10-01' AND f.started_at_id < TIMESTAMP '2026-11-01' AND s.capacity>0
GROUP BY s.station_id,s.station_name,s.capacity ORDER BY departures_per_dock DESC LIMIT 10;

-- BQ2: Busiest hours on weekdays and weekends
SELECT CASE WHEN EXTRACT(ISODOW FROM f.started_at_id) <= 5
            THEN 'Weekday' ELSE 'Weekend' END AS day_type,
       EXTRACT(HOUR FROM f.started_at_id) AS hour, COUNT(*) AS departures
FROM gold.fact_ride f WHERE f.started_at_id >= '2026-10-01' AND f.started_at_id < '2026-11-01'
GROUP BY 1,2 ORDER BY 1,2;

-- BQ3: Morning net bike outflow, 07:00-09:00
SELECT s.station_name,SUM(m.departures) - SUM(m.arrivals) AS net_outflow
FROM (
  SELECT start_station_id AS station_id,COUNT(*) AS departures,0 AS arrivals
  FROM gold.fact_ride
  WHERE started_at_id >= '2026-10-01' AND started_at_id < '2026-11-01'
    AND EXTRACT(HOUR FROM started_at_id)>=7 AND EXTRACT(HOUR FROM started_at_id)<9
  GROUP BY start_station_id
  UNION ALL
  SELECT end_station_id AS station_id,0 AS departures,COUNT(*) AS arrivals
  FROM gold.fact_ride
  WHERE end_at_id >= '2026-10-01' AND end_at_id < '2026-11-01'
    AND EXTRACT(HOUR FROM end_at_id)>=7 AND EXTRACT(HOUR FROM end_at_id)<9
  GROUP BY end_station_id
) m
JOIN gold.dim_station s ON m.station_id=s.station_id
GROUP BY s.station_id,s.station_name
HAVING SUM(m.departures) - SUM(m.arrivals)>0
ORDER BY net_outflow DESC LIMIT 10;

-- BQ4: Evening net bike inflow, 17:00-19:00
SELECT s.station_name,SUM(m.arrivals) - SUM(m.departures) AS net_inflow
FROM (
  SELECT start_station_id AS station_id,COUNT(*) AS departures,0 AS arrivals
  FROM gold.fact_ride
  WHERE started_at_id >= '2026-10-01' AND started_at_id < '2026-11-01'
    AND EXTRACT(HOUR FROM started_at_id)>=17 AND EXTRACT(HOUR FROM started_at_id)<19
  GROUP BY start_station_id
  UNION ALL
  SELECT end_station_id AS station_id,0 AS departures,COUNT(*) AS arrivals
  FROM gold.fact_ride
  WHERE end_at_id >= '2026-10-01' AND end_at_id < '2026-11-01'
    AND EXTRACT(HOUR FROM end_at_id)>=17 AND EXTRACT(HOUR FROM end_at_id)<19
  GROUP BY end_station_id
) m
JOIN gold.dim_station s ON m.station_id=s.station_id
GROUP BY s.station_id,s.station_name
HAVING SUM(m.arrivals) - SUM(m.departures)>0
ORDER BY net_inflow DESC LIMIT 10;

-- BQ5: Station departures by bike type
SELECT s.station_name,b.rideable_type,COUNT(*) AS departures,s.capacity,
       ROUND(COUNT(*) * 1.0 / s.capacity,2) AS departures_per_dock
FROM gold.fact_ride f
JOIN gold.dim_station s ON f.start_station_id=s.station_id
JOIN gold.dim_bike b ON f.rideable_type_id=b.bike_id
WHERE f.started_at_id >= '2026-10-01' AND f.started_at_id < '2026-11-01' AND s.capacity>0
GROUP BY s.station_id,s.station_name,b.rideable_type,s.capacity
ORDER BY s.station_name,b.rideable_type;

-- BQ6: Busiest routes between different stations
SELECT a.station_name AS origin,b.station_name AS destination,COUNT(*) AS trips
FROM gold.fact_ride f JOIN gold.dim_station a ON f.start_station_id=a.station_id
JOIN gold.dim_station b ON f.end_station_id=b.station_id
WHERE f.started_at_id >= TIMESTAMP '2026-10-01' AND f.started_at_id < TIMESTAMP '2026-11-01'
AND f.start_station_id <> f.end_station_id
GROUP BY a.station_id,a.station_name,b.station_id,b.station_name ORDER BY trips DESC LIMIT 5;

