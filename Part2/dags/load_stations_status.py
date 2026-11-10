from airflow import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator, ShortCircuitOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook
import json
import pendulum
import requests
from datetime import timedelta, datetime, timezone
import pytz

STATIONS_INFORMATIONS_API = "https://gbfs.citibikenyc.com/gbfs/2.3/gbfs.json" # URL of the Bikes City API
CONN_ID = "bikes_db" # Name of database
FILE_NAME = "stations_status.json" # Name of the file to store the data between functions

#Arguments for the DAG Airflow
default_args = {
    "owner": "airflow", # User owner
    "retries": 2, # Number of retries if it failed
    "retry_delay": timedelta(seconds=30), # Delay between each retry
}

def fetch_stations_status(**context):
    # Init of database communication
    pg = PostgresHook(postgres_conn_id=CONN_ID)

    # To convert the database values into UTC values
    utc=pytz.UTC

    actual_date = datetime.now(timezone.utc) # Fetch of the current date (UTC format)
    actual_date = actual_date.replace(second=0, microsecond=0) # Replace the seconds and microseconds by 0 because it's not important for us
    
    # Fetch the date of the last load in the database
    last_load_date = pg.get_first("SELECT _loaded_at FROM bronze.citibikenyc_stations_status ORDER BY _loaded_at DESC LIMIT 1")

    # If the database is empty or if the date of the last load isn't the current date
    if last_load_date is None or utc.localize(last_load_date[0]) < actual_date :
        
        # Fetch the Bikes City API informations
        response = requests.get(STATIONS_INFORMATIONS_API)
        response.raise_for_status() # Exception if something happend

        # Convert the response into JSON format
        json_content = response.json()
    
        station_status_url = "" # To store the URL station status value

        # Iterate on differents values into the Bikes City API 
        for element in json_content["data"]["en"]["feeds"] : # If "station_information" is found
            
            if element["name"] == "station_status":
                # Get the URL value 
                station_status_url = element["url"]
        
        # Fetch the station status
        data_response = requests.get(station_status_url)
        data_response.raise_for_status()

        # Convert the response into JSON format into "data" -> "stations" hierarchy
        stations_status = data_response.json()["data"]["stations"]
        
        with open(FILE_NAME, "w") as f: # Create a JSON file to save values
            json.dump(stations_status, f) # Write in the JSON file

        return {"actual_date": actual_date} # Return the actual date in the logs

    # If the date of the last load is the same of the current date (we look the minutes)
    elif (utc.localize(last_load_date[0]) == actual_date): 
        print("The data is already loaded")
        return False # We return False to skip the others functions (ShortCircuitOperator)
    else :
        raise Exception("Unexpected error happened")

## Function to store the station status
def store__stations_status(**context) :

    ## Get of the values of the last function
    ti = context["ti"] # We get the Airflow context
    payload = ti.xcom_pull(task_ids="fetch_stat_status") # Get the values of the last function (return)
    actual_date = payload["actual_date"] # Get the "actual_date" value of the last function

    ## Init of database communication
    pg = PostgresHook(postgres_conn_id=CONN_ID)

    ## Get the JSON file
    with open(FILE_NAME, "r") as f:  
        ## Store the data in the database      
        pg.run("""
            INSERT INTO bronze.citibikenyc_stations_status (
                _loaded_at, 
                stat_status
            ) VALUES (%s, %s)""", 
            parameters=(
                actual_date, 
                json.dumps(json.load(f))
            )
        )

## Quality check after the ingestion
def quality_check(**context) :

    ## Get of the values of the last function
    ti = context["ti"] # We get the Airflow context
    payload = ti.xcom_pull(task_ids="fetch_stat_status") # Get the values of the last function (return)
    actual_date = payload["actual_date"] # Get the "actual_date" value of the last function

    ## Init of database communication
    pg = PostgresHook(postgres_conn_id=CONN_ID)

    ## Fetch of the rows number inserted
    rows_inseted = pg.get_first("SELECT COUNT(*) FROM bronze.citibikenyc_stations_status WHERE _loaded_at = %s", parameters=(actual_date,))

    if rows_inseted[0] == 0 : 
        raise Exception("Nothing inserted in the database")


with DAG(
    dag_id="stations_status_loader",
    description="Fetch the stations status datasets and store it into the Bronze layer",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule="* * * * *", # Execute the DAG every minute (the TTL (Time To Live) in the Bikes City API is of 60 seconds)
    catchup=False,
    max_active_runs=1,
    default_args=default_args,
    tags=["bronze layer"], # For the bronze layer
) as dag:

    fetch_task = ShortCircuitOperator( # "ShortCircuitOperator" to skip other functions if the data is already loaded
        task_id="fetch_stat_status",
        python_callable=fetch_stations_status,
    )

    store_task = PythonOperator(
        task_id="store_stat_status",
        python_callable=store__stations_status,
    )

    quality_task = PythonOperator(
        task_id="quality_data_check",
        python_callable=quality_check,
    )
    
    fetch_task >> store_task >> quality_task # Execution order