# KPA API

FastAPI service for the Khan Placement Agency platform. This directory contains
the backend foundations only — DB layer, auth, and domain code land in
follow-on plans.

## Requirements

- Python 3.12
- [uv](https://docs.astral.sh/uv/) 0.5+
- Docker (for container builds + future local Postgres/Redis)

## First-time setup

```bash
cd api
uv sync
cp .env.example .env   # adjust as needed
```

## Run locally

```bash
KPA_ENV=local KPA_SERVICE_NAME=kpa-api uv run uvicorn kpa.main:app --reload --port 8000
```

Then:

```bash
curl http://127.0.0.1:8000/health
```

## Tests

```bash
uv run pytest -v
```

## Lint, format, type-check

```bash
uv run ruff check src/ tests/
uv run ruff format src/ tests/
uv run mypy
```

## Container build

```bash
docker build -t kpa-api:dev .
docker run --rm -e KPA_ENV=local -e KPA_SERVICE_NAME=kpa-api \
  -e KPA_LOG_LEVEL=INFO -e KPA_LOG_FORMAT=text \
  -p 8000:8000 kpa-api:dev
```

## Configuration

All settings are read from environment variables prefixed `KPA_`:

| Variable           | Required | Default | Purpose                         |
| ------------------ | -------- | ------- | ------------------------------- |
| `KPA_ENV`          | yes      | —       | `local` \| `dev` \| `staging` \| `prod` |
| `KPA_SERVICE_NAME` | yes      | —       | Reported in `/health`           |
| `KPA_LOG_LEVEL`    | no       | `INFO`  | Stdlib log level                |
| `KPA_LOG_FORMAT`   | no       | `text`  | `text` (key=value) or `json`    |

The service refuses to boot if required variables are missing or invalid.

## Project layout

```
api/
├── src/kpa/
│   ├── app_factory.py        # create_app() — middlewares + routes
│   ├── main.py               # uvicorn entry point
│   ├── settings.py
│   ├── middleware/
│   │   ├── request_id.py     # X-Request-Id propagation
│   │   └── error_handler.py  # RFC 7807 problem+json
│   ├── observability/
│   │   └── logging.py        # structlog config
│   └── routes/
│       └── health.py         # GET /health
└── tests/
```
