# Data

This directory contains the source data snapshots used for the Citi Bike
analysis project.

## Files

- [`JC-202609-citibike-tripdata.csv`](./JC-202609-citibike-tripdata.csv) —
  monthly trip records. Each row represents one completed trip; columns include
  ride and bike types, start and end times, station details, coordinates, and
  rider type.
- [`station_information.json`](./station_information.json) — station metadata
  in GBFS format, including station IDs, names, locations, and dock capacity.

## Sources

- Trip data: [Citi Bike trip data archive](https://s3.amazonaws.com/tripdata/index.html)
- Station metadata:
  [Citi Bike GBFS station information](https://gbfs.lyft.com/gbfs/1.1/bkn/es/station_information.json)

## Using the data

The files are stored directly in this directory.
Keep the source snapshots unchanged; write cleaned or transformed data to
separate files or database tables.
