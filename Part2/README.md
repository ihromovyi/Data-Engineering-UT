## How to Run

```
docker compose up -d
```

## Credentials

| Component      | Username            | Password      | Port |
| -------------- | ------------------- | ------------- | ---- |
| **airflow-db** | `airflow`           | `airflow`     | 5432 |
| **prices-db**  | `bikes_user`       | `bikes_pass` | 5433 |
| **pgAdmin**    | `admin@example.com` | `admin`       | 5050 |

These are the defaults. Override any of them in `.env` (see `.env.example`).

Access pgAdmin at:  
[http://localhost:5050](http://localhost:5050)

Access Airflow at:  
[http://localhost:8080](http://localhost:8080)

Connecting `prices-db` through PgAdmin

| Field                    | Value                                                |
| ------------------------ | ---------------------------------------------------- |
| **Host name / address**  | `bikes-db` *(use service name from docker-compose)* |
| **Port**                 | `5432`                                               |
| **Maintenance database** | `bikes_db`                                          |
| **Username**             | `bikes_user`                                        |
| **Password**             | `bikes_pass`                                        |