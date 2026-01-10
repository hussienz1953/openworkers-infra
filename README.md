# OpenWorkers Infrastructure

Self-hosted Cloudflare Workers runtime.

## Getting Started

- **[Docker Compose](./GETTING_STARTED.md)** - Self-hosted deployment
- **[Local Development](./GETTING_STARTED_LOCAL.md)** - Contributing to OpenWorkers

## Stack

| Service | Description |
| ------- | ----------- |
| postgres | PostgreSQL database |
| nats | Message queue for worker communication |
| [postgate](https://github.com/openworkers/postgate) | HTTP proxy for PostgreSQL (query validation, multi-tenant) |
| [openworkers-api](https://github.com/openworkers/openworkers-api) | REST API |
| [openworkers-runner](https://github.com/openworkers/openworkers-runner) | Worker runtime (V8 isolates) |
| [openworkers-logs](https://github.com/openworkers/openworkers-logs) | Log aggregator |
| [openworkers-scheduler](https://github.com/openworkers/openworkers-scheduler) | Cron job scheduler |
| [openworkers-dash](https://github.com/openworkers/openworkers-dash) | Dashboard UI |
| openworkers-proxy | Nginx reverse proxy |

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

## Scripts

```bash
# Database backup/restore
./database.sh backup
./database.sh restore <file>
./database.sh migrate <sql_file>
./database.sh psql
```
