# Getting Started (Docker Compose)

Self-hosted deployment using Docker Compose.

## Prerequisites

- Docker + Docker Compose
- TLS certificates (for HTTPS)
- A domain name pointing to your server

## 1. Configure environment

```bash
cp .env.example .env
# Edit .env with your values
```

**Required variables:**

- `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` - Database credentials
- `GITHUB_CLIENT_ID` / `GITHUB_CLIENT_SECRET` - OAuth (for dashboard login)
- `JWT_ACCESS_SECRET` / `JWT_REFRESH_SECRET` - Auth tokens (generate random strings)
- `HTTP_TLS_CERTIFICATE` / `HTTP_TLS_KEY` - TLS cert paths

## 2. Start database

```bash
docker compose up -d postgres
# Wait for it to be healthy
docker compose ps
```

## 3. Run migrations

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

## 4. Generate API token

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

## 5. Start all services

```bash
docker compose up -d
```

## 6. Verify

```bash
docker compose ps
docker compose logs -f
```

Dashboard should be available at `https://your-domain/`.

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

## Database management

Use the `database.sh` script:

```bash
# Backup
./database.sh backup

# Restore
./database.sh restore ~/backups/openworkers/openworkers-2025-01-10.dump

# Run a migration
./database.sh migrate path/to/migration.sql

# Interactive psql
./database.sh psql
```
