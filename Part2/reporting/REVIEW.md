# After-action review (AAR)

Reviewed against the supplied Project 2 requirements on 25 November 2026. This review separates report coverage from implementation completeness.

## Overall finding

The report covers the requested topics and format. The deployed project demonstrated JSON ingestion, a six-model Gold warehouse, eighteen passing dbt tests and unchanged ride counts on a repeated trip batch. It does **not** yet satisfy every implementation requirement: complete trip-load recovery, keyed incremental Gold updates and reproducible snapshot replay remain gaps. The Airflow overview also shows historical failures; successful later runs do not erase those limitations.

## Requirement check

| Requirement | Result | Evidence / remaining action |
| --- | --- | --- |
| Reuse/refine the brief, KPIs and questions | Covered | Report section 1; six query/result pairs in this folder. |
| Explain changes from Project 1 | Covered | Report section 3 and schema documentation. |
| At least two sources | Demonstrated | Trip archive and GBFS feeds; deployed Bronze/Gold tables and logs. |
| Automated Airflow ingestion | Demonstrated for API feeds; partial for trips | Successful API load/check tasks. The original trip store failed; later trip runs skipped it. |
| Basic parameterisation | Partial | Current date chooses the previous month; explicit historical month/snapshot replay is unavailable. |
| At least one pipeline quality check | Demonstrated | Bronze row-presence checks; 18 configured dbt tests passed. These do not validate all station relationships or source completeness. |
| Idempotence for the same input/date | Partial | Verified trip rerun: 356,772 rows before/after, zero duplicate ride IDs. Recovery of a partially failed batch and fixed API replay are unproven. |
| Database engine and workload justification | Covered | PostgreSQL: local deployment, JSONB, dbt, dimensional joins and batch volumes; report section 2. |
| Load data; distinct Bronze/Gold layers | Demonstrated | Separate schemas; API arrays in Bronze, six active Gold models. Silver is optional and omitted. |
| Analytical physical design and incremental updates | Partial / incremental requirement not met | Queries execute, but models rebuild tables; no keyed incremental models or explicit analytical indexes are defined. |
| At least one fact and three dimensions; explicit grain | Demonstrated | Two facts and four dimensions. Ride IDs are unique in the measured batch; status repeats station totals across expanded type entries. |
| At least one dbt test | Demonstrated | 18 tests passed; build summary PASS=24 includes 6 models. |
| dbt YAML documentation | Present | `citibike_dbt/models/gold_schema.yml`; key model/column descriptions and tests. |
| Express dbt dependencies | Present | `source()`/`ref()` and the dependency diagram in this README. |
| Airflow invokes dbt and refreshes Gold | Demonstrated | Successful `dbt_pipeline` task log and populated Gold. Source-completion ordering is not automatically enforced. |
| Each required DAG runs start-to-finish | Partial | API paths complete; a successful skipped trip rerun is not proof of a complete successful initial trip load. |
| Optional JSON integration bonus | Supported | API extraction, JSONB storage, array expansion, typed station rows, comparison and measured example are in the report/model code. Credit remains the lecturer's decision, maximum +2 shared. |
| Complete code and setup README | Code present; gaps documented | DAGs, dbt, SQL and configuration are published. Reproduction steps and known failure/replay limits are in this folder. |
| Airflow/dbt diagrams or screenshots | Present | `airflow-overview.png`, schema diagram and README dependency diagram. |
| Adapted analytical SQL and results | Present for all six refined questions | `queries.sql` and six result CSVs. Original Project 1 queries include superseded questions and old DDL. |
| Maximum five main pages, 11-point body | Checked | Final Report.pdf has four pages. Code/figure labels use smaller type; body is 11-point. |
| Representative pipelines, architecture and clear links | Covered | Report sections 2–5; repository/code/reproduction links at the end. |
| Bonus comparison, relevance and results | Covered | Station capacity example and JSONB-versus-typed-table explanation. |
| Member roles and percentages | Covered | Three equal one-third shares, displayed as 33.3% each with rounding explained. |
| LLM disclosure and chat links | Present; link coverage limited to supplied chat | AI assistance is disclosed and the supplied Gemini conversation is linked. No public link was supplied for the additional AI sessions. |

## What worked

- The SQL-model schema was confirmed using live `information_schema.columns`.
- Six dbt models built and eighteen configured tests passed.
- Bronze and Gold each contained 356,772 distinct trip IDs, with no duplicate rides.
- Repeating the trip task left those counts unchanged.
- The API example mapped station capacity 45 into an integer Gold column; 2,519 source station objects matched the station-table count.
- Correcting September filters to October returned usable analytical results.

## What needs changing next

1. Track batch completion and recover failed trip loads safely; a timestamp alone currently allows an incomplete batch to be skipped.
2. Introduce an explicit input month and stored API snapshot identity for repeatable input replay.
3. Implement and justify keyed incremental Gold loading rather than only full rebuilds.
4. Make Gold refresh wait for required source ingestion.
5. Broaden quality checks for missing station relationships and completeness before interpreting results operationally.

The current partial batch is suitable for demonstrating transformations and SQL. It is not a complete monthly operational report and cannot establish actual unmet demand, revenue, profit or monthly dock saturation.
