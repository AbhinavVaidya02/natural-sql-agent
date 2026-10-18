# Task Tracker

Phase-by-phase tasks for the Natural Language to SQL Analytics Agent. Phases follow the roadmap in [readme.md](readme.md).

Legend: `[x]` done · `[ ]` to do · `[~]` skipped / deferred

## Phase 1 — Data and database

- [x] Download the Olist dataset into `archive/`
- [x] Document table relationships and verify keys, row counts, and orphans ([archive/dataset_relationships.md](archive/dataset_relationships.md))
- [x] Set up PostgreSQL (local PostgreSQL 16 service)
- [x] Create the `nl_sql_analytics` database
- [x] Create tables in the `public` schema with types, keys, indexes, and column comments ([scripts/create_tables.sql](scripts/create_tables.sql))
- [x] Create a virtual environment, `requirements.txt`, `.env.example`, `.gitignore`
- [x] Load the CSVs and verify row counts ([scripts/load_olist_data.py](scripts/load_olist_data.py))
- [~] Create a read-only database role ([scripts/create_readonly_role.sql](scripts/create_readonly_role.sql) is written but not run; the app connects as `postgres` for now)
- [x] Fix `readme.md`: removed the Python/pypandoc wrapper so it is plain Markdown
- [x] Document key business definitions ([docs/business_definitions.md](docs/business_definitions.md))

## Phase 2 — Basic text-to-SQL

- [ ] Choose the LLM provider and model; add its package to `requirements.txt`
- [ ] Add `app/config.py` to load settings from `.env`
- [ ] Add `app/database/connection.py` (SQLAlchemy engine)
- [ ] Add `app/database/schema.py` to read tables, columns, keys, and `COMMENT ON` descriptions
- [ ] Write the SQL-generation prompt (`app/agent/prompts.py`)
- [ ] Add `app/database/executor.py` with a read-only transaction, statement timeout, and row limit
- [ ] Add Pydantic request/response models (`app/schemas/requests.py`)
- [ ] Add the `POST /analytics/query` endpoint returning SQL, columns, and rows
- [ ] Test with a few hand-checked questions

## Phase 3 — Validation and recovery

- [ ] Add SQL parsing and policy checks with SQLGlot (`app/services/sql_validator.py`): single statement, SELECT only, allowed tables only
- [ ] Unit tests for the validator (`tests/test_sql_validator.py`)
- [ ] Revisit the read-only role (see Phase 1)
- [ ] Add bounded retries for recoverable SQL errors (`MAX_SQL_RETRIES`)
- [ ] Ask clarifying questions for ambiguous requests

## Phase 4 — LangGraph orchestration

- [ ] Define workflow state (`app/agent/state.py`)
- [ ] Add nodes: question analysis, schema retrieval, SQL generation, validation, execution, correction, summarization (`app/agent/nodes.py`)
- [ ] Wire the graph with conditional edges for rejected queries and recoverable failures (`app/agent/graph.py`)
- [ ] Set iteration limits and handle terminal failures
- [ ] Add result summarization grounded in returned rows (`app/services/summarizer.py`)
- [ ] Return a chart specification when the result suits a chart

## Phase 5 — React frontend

- [ ] Scaffold the React app with Vite in `frontend/`
- [ ] Add the API client (`src/api/client.js`) and `VITE_API_BASE_URL`
- [ ] Build the question input and answer card
- [ ] Show the generated SQL (SqlViewer)
- [ ] Add a sortable, paginated results table (TanStack Table)
- [ ] Render charts from the chart specification (Recharts)
- [ ] Show assumptions and clarification questions
- [ ] Handle loading, empty, and error states
- [ ] Add CSV download
- [ ] Configure CORS on the backend for the frontend origin

## Phase 6 — Evaluation and presentation

- [ ] Write evaluation questions with independently verified expected results (`evaluation/questions.json`)
- [ ] Add evaluation tests (`tests/test_evaluation.py`)
- [ ] Measure execution accuracy, result correctness, safety rejections, latency, and token cost
- [ ] Add API tests (`tests/test_api.py`)
- [ ] Add Dockerfiles and `compose.yaml` for the backend, frontend, and PostgreSQL
- [ ] Document limitations and finalize the README
