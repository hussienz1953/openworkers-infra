# Getting Started (Local Development)

Development setup for contributing to OpenWorkers.

## Prerequisites

- Rust (latest stable)
- Bun
- Node.js 20+ (for Angular CLI)
- Docker (for PostgreSQL and NATS)

## Clone repositories

```bash
mkdir openworkers && cd openworkers

git clone https://github.com/openworkers/openworkers-infra.git
git clone https://github.com/openworkers/openworkers-cli.git
git clone https://github.com/openworkers/openworkers-runner.git
git clone https://github.com/openworkers/openworkers-api.git
git clone https://github.com/openworkers/openworkers-dash.git
git clone https://github.com/openworkers/openworkers-scheduler.git

# Optional: runtime libraries
git clone https://github.com/openworkers/openworkers-core.git
git clone https://github.com/openworkers/openworkers-runtime-v8.git
git clone https://github.com/openworkers/postgate.git
```

## 1. Start infrastructure

**Option A: Docker**

```bash
cd openworkers-infra
docker compose up -d postgres nats
```

**Option B: Local install**

If you have PostgreSQL and NATS installed locally, just start them:

```bash
# macOS (Homebrew)
brew services start postgresql
brew services start nats-server

# Or manually
pg_ctl start
nats-server
```

## 2. Setup database

**If using Docker:**

```bash
cd openworkers-infra
for f in ../openworkers-cli/migrations/*.sql; do
  echo "Applying $f..."
  docker compose exec -T postgres psql -U openworkers -d openworkers < "$f"
done
```

**If using local PostgreSQL:**

```bash
cd openworkers-cli
for f in migrations/*.sql; do
  echo "Applying $f..."
  psql -U openworkers -d openworkers < "$f"
done
```

## 3. Start Postgate

```bash
cd ../postgate

# Create .env
cat > .env << 'EOF'
DATABASE_URL=postgres://openworkers:openworkers@localhost:5432/openworkers
POSTGATE_PORT=3001
EOF

cargo run
```

Postgate runs on `http://localhost:3001`.

## 4. Start API

```bash
cd ../openworkers-api

# Create .env
cat > .env << 'EOF'
PORT=3000
POSTGATE_URL=http://localhost:3001
POSTGATE_TOKEN=dev-token
NATS_URL=localhost:4222
JWT_ACCESS_SECRET=dev-access-secret
JWT_REFRESH_SECRET=dev-refresh-secret
GITHUB_CLIENT_ID=your-github-client-id
GITHUB_CLIENT_SECRET=your-github-client-secret
EOF

bun install
bun run dev
```

API runs on `http://localhost:3000`.

## 5. Start Runner

```bash
cd ../openworkers-runner

# Create .env
cat > .env << 'EOF'
NATS_URL=localhost:4222
DATABASE_URL=postgres://openworkers:openworkers@localhost:5432/openworkers
RUST_LOG=info
EOF

# Generate V8 snapshot (first time only)
cargo run --features v8 --bin snapshot

# Run
cargo run --features v8
```

Runner is an HTTP server on port 8080. It loads worker code from PostgreSQL and executes it in V8. Logs are published to NATS, and scheduled tasks are received from NATS.

## 6. Start Dashboard

```bash
cd ../openworkers-dash

bun install
bun start
```

Dashboard runs on `http://localhost:4200` with proxy to API.

## 7. Start Scheduler (optional)

```bash
cd ../openworkers-scheduler

cat > .env << 'EOF'
NATS_URL=localhost:4222
DATABASE_URL=postgres://openworkers:openworkers@localhost:5432/openworkers
EOF

bun install
bun run dev
```

## Development workflow

### Runner (Rust)

```bash
cd openworkers-runner

# Run tests
cargo test --features v8

# Run specific test
cargo test --features v8 test_name

# After modifying runtime JS (in openworkers-runtime-v8)
cargo run --features v8 --bin snapshot
```

### API (TypeScript/Bun)

```bash
cd openworkers-api

bun run dev     # Development with hot reload
bun test        # Run tests
```

### Dashboard (Angular)

```bash
cd openworkers-dash

bun start       # Development server
bun run build   # Production build
```

## Ports summary

| Service    | Port |
| ---------- | ---- |
| PostgreSQL | 5432 |
| NATS       | 4222 |
| Postgate   | 3001 |
| API        | 3000 |
| Dashboard  | 4200 |
| Runner     | 8080 |

## Tips

- Use `./database.sh psql` from infra to quickly access the database
- Dashboard proxies `/api` requests to the API (configured in `proxy.conf.json`)
- Runner logs show worker execution details with `RUST_LOG=debug`
