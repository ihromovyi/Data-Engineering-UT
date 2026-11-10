from airflow import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator, ShortCircuitOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
import pendulum
import requests
from datetime import timedelta, datetime, timezone
import zipfile
from io import TextIOWrapper
import csv
from dateutil.relativedelta import relativedelta

TRIPS_API = "https://s3.amazonaws.com/tripdata/" # URL of the trips API
API_NAME_FILE = "-citibike-tripdata.zip" # File name in the API
CONN_ID = "bikes_db" # Name of the database
NAME_FILE = "zipfiledata.zip" # Name of the file to store the data between functions

#Arguments for the DAG Airflow
default_args = {
    "owner": "airflow", # User owner
    "retries": 2, # Number of retries if it failed
    "retry_delay": timedelta(seconds=30), # Delay between each retry
}

## Function to fetch trips information
def fetch_trips(**context):

    # Init of database communication
    pg = PostgresHook(postgres_conn_id=CONN_ID)

    # Get a 1 month to compute the last month later
    delta = relativedelta(months=1)

    # Fetch of the current date (UTC format) without time
    actual_date = datetime.now(timezone.utc).date()
    # Replace the day by 1 because it's not important for us
    actual_date = actual_date.replace(day=1)

    # Fetch the date of the last load in the database
    last_load_date = pg.get_first("SELECT _loaded_at FROM bronze.citibikenyc_trips ORDER BY _loaded_at DESC LIMIT 1")

    # Get the last month
    last_month_date = actual_date - delta

    # To take the trips file, we need to add a "0" if the month returned is between 0 and 9 
    last_month = "0" + str(last_month_date.month) if 1 <= last_month_date.month <= 9 else last_month_date.month

    # If the database is empty or if the date of the last load isn't the current date
    if last_load_date is None or  last_load_date[0] < actual_date:

        # Fetch the trips file
        response = requests.get(TRIPS_API + str(last_month_date.year) + str(last_month) + API_NAME_FILE)
        response.raise_for_status() # Exception if something happend

        # Create a ZIP file to save values (into binary formart "wb")
        with open(NAME_FILE, "wb") as f:
            f.write(response.content) # Write in the ZIP file

        return {"actual_date": actual_date} # Return the actual date in the logs

    # If the date of the last load is the same of the current date (we look the month)               
    elif ( last_load_date[0] == actual_date): 
        print("The data is already loaded")
        return False# We return False to skip the others functions (ShortCircuitOperator)
    else :
        raise Exception("Unexpected error happened")

## Function to store the trips informations
def store_trips(**context) :

    ## Get of the values of the last function
    ti = context["ti"] # We get the Airflow context
    payload = ti.xcom_pull(task_ids="fetch_trips") # Get the values of the last function (return)
    actual_date = payload["actual_date"] # Get the "actual_date" value of the last function

    ## Init of database communication
    pg = PostgresHook(postgres_conn_id=CONN_ID)

    ## Get the ZIP file
    with zipfile.ZipFile(NAME_FILE, "r") as zf:

        # Iterate each file into the ZIP file
        for file in zf.namelist() : 
            # Get the CSV file
            with zf.open(file) as myfile:

                # Convert data content into UTF-8 data to read it
                text_stream = TextIOWrapper(myfile, encoding='utf-8')
                # Read the csv file and build a dictionary
                file_csv = csv.DictReader(text_stream, delimiter=',')

                # for each row in the dictionnary
                for row in file_csv : 
                    ## Store the data in the database
                    pg.run("""
                        INSERT INTO bronze.citibikenyc_trips (
                            _loaded_at, 
                            ride_id, 
                            rideable_type, 
                            started_at, 
                            ended_at, 
                            start_station_name, 
                            start_station_id, 
                            end_station_name, 
                            end_station_id, 
                            start_lat, 
                            start_lng, 
                            end_lat, 
                            end_lng, 
                            member_casual
                        ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""", 
                        parameters=(
                            actual_date, 
                            row["ride_id"],
                            row["rideable_type"],
                            row["started_at"],
                            row["ended_at"],
                            row["start_station_name"],
                            row["start_station_id"],
                            row["end_station_name"],
                            row["end_station_id"],
                            row["start_lat"],
                            row["start_lng"],
                            row["end_lat"],
                            row["end_lng"],
                            row["member_casual"]
                        )
                    )

## Quality check after the ingestion
def quality_check(**context) :
    
    ## Get of the values of the last function
    ti = context["ti"] # We get the Airflow context
    payload = ti.xcom_pull(task_ids="fetch_trips") # Get the values of the last function (return)
    actual_date = payload["actual_date"] # Get the "actual_date" value of the last function

    ## Init of database communication
    pg = PostgresHook(postgres_conn_id=CONN_ID)

    ## Fetch of the rows number inserted
    rows_inseted = pg.get_first("SELECT COUNT(*) FROM bronze.citibikenyc_trips WHERE _loaded_at = %s", parameters=(actual_date,))

    if rows_inseted[0] == 0 : 
        raise Exception("Nothing inserted in the database")


with DAG(
    dag_id="trip_datasets_loader",
    description="Fetch the trip datasets and store it into the Bronze layer",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule="0 0 27 * *", # Execute the DAG one time per month (at the end) because the trips data are plublished only at the end of the month
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["bronze layer"], # For the bronze layer
) as dag:

    fetch_task = ShortCircuitOperator( # "ShortCircuitOperator" to skip other functions if the data is already loaded
        task_id="fetch_trips",
        python_callable=fetch_trips,
    )

    store_task = PythonOperator(
        task_id="store_trips",
        python_callable=store_trips,
    )

    quality_task = PythonOperator(
        task_id="quality_data_check",
        python_callable=quality_check,
    )
    
    fetch_task >> store_task >> quality_task  # Execution order