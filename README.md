# OpenWorkers Infrastructure

Self-hosted Cloudflare Workers runtime.

## Prerequisites

- Docker + Docker Compose
- TLS certificates (for HTTPS)

## Stack

| Service | Description |
| ------- | ----------- |
| postgres | PostgreSQL database |
| nats | Message queue for worker communication |
| [postgate](https://github.com/openworkers/postgate) | HTTP proxy for PostgreSQL (query validation, multi-tenant) |
| [openworkers-api](https://github.com/openworkers/openworkers-api) | REST API |
| [openworkers-runner](https://github.com/openworkers/openworkers-runner) | Worker runtime (V8 isolates) × 3 replicas |
| [openworkers-logs](https://github.com/openworkers/openworkers-logs) | Log aggregator |
| [openworkers-scheduler](https://github.com/openworkers/openworkers-scheduler) | Cron job scheduler |
| [openworkers-dash](https://github.com/openworkers/openworkers-dash) | Dashboard UI |
| openworkers-proxy | Nginx reverse proxy |

## Quick Start

### 1. Configure environment

```bash
cp .env.example .env
# Edit .env with your values
```

**Required variables:**

- `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` - Database credentials
- `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` - OAuth (for dashboard login)
- `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` - Auth tokens (generate random strings)
- `HTTP_TLS_CERTIFICATE` / `HTTP_TLS_KEY` - TLS cert paths

### 2. Start database

```bash
docker compose up -d postgres
# Wait for it to be healthy
docker compose ps
```

### 3. Run migrations

```bash
# Clone the CLI repo (if not already)
git clone https://github.com/openworkers/openworkers-cli.git

# Apply migrations
for f in openworkers-cli/migrations/*.sql; do
  echo "Applying $f..."
  docker compose exec -T postgres psql -U $POSTGRES_USER -d $POSTGRES_DB < "$f"
done
```

This creates all tables including Postgate compatibility views.

### 4. Generate API token

The migrations created a database config for the API. Generate a token for it:

```bash
# Start Postgate
docker compose up -d postgate

# Generate API token
docker compose exec postgate postgate gen-token \
  aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa api \
  --permissions SELECT,INSERT,UPDATE,DELETE
```

Copy the generated token to `.env`:

```
POSTGATE_TOKEN=pg_xxx...
```

### 5. Start all services

```bash
docker compose up -d
```

### 6. Verify

```bash
docker compose ps
docker compose logs -f
```

Dashboard should be available at `https://your-domain/`.

## Architecture

```
                         ┌─────────────────┐
                         │  nginx (proxy)  │
                         └────────┬────────┘
                                  │
         ┌───────────────┬────────┴──┬───────────────┐
         │               │           │               │
         │               │           │               │
┌────────┸────────┐ ┌────┸────┐ ┌────┸────┐ ┌────────┸────────┐
│   dashboard     │ │  api    │ │ logs *  │ │  runner (x3) *  │
└─────────────────┘ └────┬────┘ └────┰────┘ └────────┰────────┘
                         │           │               │
                         │           │               │
                ┌────────┸────────┐  │      ┌────────┸────────┐
                │   postgate *    │  └──────┥      nats       │
                └─────────────────┘         └────────┰────────┘
                                                     │
                                                     │
                ┌─────────────────┐           ┌──────┴───────┐
         * ─────┥   PostgreSQL    │           │ scheduler *  │
                └─────────────────┘           └──────────────┘

```

**Single database:** Postgate uses views (`postgate_databases`, `postgate_tokens`) that map to OpenWorkers tables.

## Useful Commands

```bash
# View logs
docker compose logs -f openworkers-api
docker compose logs -f openworkers-runner

# Restart a service
docker compose restart openworkers-api

# Shell into postgres
docker compose exec postgres psql -U openworkers -d openworkers

# Stop all services
docker compose down

# Stop all + remove volumes (DANGER: deletes data)
docker compose down -v
```

## How Database Access Works

```
Worker JS code          Runner (Rust)              Postgate (lib)         PostgreSQL
      │                      │                           │                    │
      │  env.DB.query(sql)   │                           │                    │
      ├─────────────────────►│                           │                    │
      │                      │  postgate::execute(sql)   │                    │
      │                      ├──────────────────────────►│                    │
      │                      │                           │  SQL query         │
      │                      │                           ├───────────────────►│
      │                      │                           │◄───────────────────┤
      │                      │◄──────────────────────────┤                    │
      │◄─────────────────────┤                           │                    │
```

- **Workers** use bindings (`env.DB.query()`) provided by the runner
- **Runner** uses Postgate as a Rust library for query validation and execution
- **Postgate HTTP** is only used by the OpenWorkers API for admin operations
- **Token** in `.env` (`POSTGATE_TOKEN`) is for the API, not for workers

## Updating

```bash
# Pull latest images
docker compose pull

# Restart with new images
docker compose up -d

# Apply new migrations if any
for f in openworkers-cli/migrations/*.sql; do
  docker compose exec -T postgres psql -U $POSTGRES_USER -d $POSTGRES_DB < "$f" 2>/dev/null || true
done
```
