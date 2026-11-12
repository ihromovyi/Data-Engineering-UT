-- Schema for the bronze layer
CREATE SCHEMA bronze;

-- Table to store raw bikes trips
CREATE TABLE IF NOT EXISTS bronze.citibikenyc_trips (
    _loaded_at DATE NOT NULL,
    ride_id VARCHAR NOT NULL,
    rideable_type VARCHAR NOT NULL,
    started_at VARCHAR NOT NULL,
    ended_at VARCHAR NOT NULL,
    start_station_name VARCHAR NOT NULL,
    start_station_id VARCHAR NOT NULL,
    end_station_name VARCHAR NOT NULL, 
    end_station_id VARCHAR NOT NULL,
    start_lat VARCHAR NOT NULL,
    start_lng VARCHAR NOT NULL,
    end_lat VARCHAR NOT NULL,
    end_lng VARCHAR NOT NULL,
    member_casual VARCHAR NOT NULL
);

-- Table to store raw station informations
CREATE TABLE IF NOT EXISTS bronze.citibikenyc_stations_informations (
    _loaded_at TIMESTAMP NOT NULL,
    stat_informations JSONB NOT NULL    
);

-- Table to store raw station status
CREATE TABLE IF NOT EXISTS bronze.citibikenyc_stations_status (
    _loaded_at TIMESTAMP NOT NULL,
    stat_status JSONB NOT NULL    
);

-- Table to store raw bikes types
CREATE TABLE IF NOT EXISTS bronze.citibikenyc_bikes_types (
    _loaded_at TIMESTAMP NOT NULL,
    bikes_types JSONB NOT NULL    
);


