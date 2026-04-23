<p align="center">
  <img src="docs/images/logo.png" alt="walrus" width="200" />
</p>

<h1 align="center">walrus</h1>

<p align="center">
  <strong>PostgreSQL backup buddy for indie hackers</strong>
</p>

<p align="center">
  <a href="https://github.com/LayFz/walrus/releases"><img src="https://img.shields.io/github/v/release/LayFz/walrus?style=flat-square&color=blue" alt="Release" /></a>
  <a href="https://github.com/LayFz/walrus/blob/main/LICENSE"><img src="https://img.shields.io/github/license/LayFz/walrus?style=flat-square" alt="License" /></a>
  <a href="https://github.com/LayFz/walrus/stargazers"><img src="https://img.shields.io/github/stars/LayFz/walrus?style=flat-square" alt="Stars" /></a>
  <a href="https://github.com/LayFz/walrus/issues"><img src="https://img.shields.io/github/issues/LayFz/walrus?style=flat-square" alt="Issues" /></a>
</p>

<p align="center">
  <a href="./docs/README_CN.md">简体中文</a> |
  <a href="./docs/README_TW.md">繁體中文</a> |
  <a href="./docs/README_JA.md">日本語</a> |
  <a href="./docs/README_FR.md">Français</a>
</p>

---

One command to back up all your PostgreSQL databases to Cloudflare R2. Designed for indie hackers — multi-project, multi-server, zero hassle.

## Features

- **Two deployment modes** — Docker container or direct connection (local/remote), unified management
- **Interactive setup** — Step-by-step guided configuration, no need to memorize flags
- **Physical backups** — Uses `pg_basebackup`, bypasses the query engine, zero impact on your app
- **WAL incremental sync** — Every 5 minutes, only transfers new data, max 5 min data loss
- **Bandwidth limiting** — Default 2MB/s upload, won't affect your production traffic
- **Multi-project** — Different databases on different servers, all organized in one R2 bucket
- **Auto-cleanup** — Default 7-day retention, synced cleanup on local and R2
- **One-click restore** — Interactive backup selection with point-in-time recovery (PITR)
- **systemd integration** — Runs as a system service, starts on boot
- **Concurrency safe** — Lock files prevent duplicate backup operations

## Quick Start

### Install

```bash
# Install latest version
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash

# Install specific version
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | WALRUS_VERSION=2.0.0 sudo -E bash
```

The installer automatically sets up `postgresql-client` if not already present.

### Setup

```bash
# 1. Configure R2 storage (interactive)
walrus config

# 2. Register a project (interactive)
walrus init

# 3. Verify everything is working
walrus status
```

`walrus init` guides you through selecting your PostgreSQL deployment mode, configures WAL archiving, registers systemd services, and runs a full end-to-end test.

## Deployment Modes

### Docker Container

PostgreSQL is running in Docker. walrus connects via the mapped port.

```bash
walrus init --mode docker \
  --project myapp \
  --container postgres \
  --host localhost --port 5432 \
  --user myuser --db mydb
```

### Direct Connection

PostgreSQL is accessible via host:port — whether it's on localhost, a remote server, or a managed service like RDS.

```bash
walrus init --mode direct \
  --project myapp \
  --host 10.0.1.5 --port 5432 \
  --user myuser --db mydb
```

> In interactive mode you don't need to remember any flags — `walrus init` will walk you through it.

## Commands

| Command | Description |
|---------|-------------|
| `walrus config` | Configure remote storage (R2/S3/MinIO) |
| `walrus init` | Register a project with interactive setup |
| `walrus backup` | Run a full physical backup |
| `walrus sync` | Sync WAL logs to R2 |
| `walrus restore` | Restore database from R2 |
| `walrus status` | Show all project statuses |
| `walrus list` | Show R2 backup details |
| `walrus logs` | View logs (`-f` for live tail) |
| `walrus service` | Manage systemd services |
| `walrus remove` | Remove a project |
| `walrus help` | Show help |

> When only one project is registered, `--project` can be omitted. Aliases: `st`=status, `ls`=list, `rm`=remove, `svc`=service.

## Service Management

walrus registers two systemd timers per project, running as a system service:

```bash
# Check service status
walrus service status

# Example output:
#   myapp
#     WAL sync:    ● Active -> Next: 2 min left
#     Full backup: ● Active -> Next: Thu 2026-04-24 03:00:00 CST

# Stop/Start
walrus service stop
walrus service start

# Disable auto-start on boot
walrus service disable
```

| Unit | Description | Frequency |
|------|-------------|-----------|
| `walrus-sync@<project>.timer` | WAL incremental sync | Every 5 min |
| `walrus-backup@<project>.timer` | Full physical backup + cleanup | Daily 03:00 |

## Restore

```bash
# Interactive restore (select backup, enter password)
walrus restore

# Restore to a specific point in time
walrus restore --project myapp --password secret \
  --target-time "2026-04-23 14:30:00+08"
```

All restores spin up a local Docker container (port 15432) for verification. Once confirmed, you can migrate the data to production.

## How It Works

```
Daily 03:00                              Every 5 min
┌──────────────────┐                     ┌─────────────────┐
│  pg_basebackup   │                     │  WAL archiving   │
│  (full physical) │                     │  (incremental)   │
└────────┬─────────┘                     └────────┬────────┘
         │                                        │
         │  --max-rate=30M                        │  new files only
         │  --checkpoint=spread                   │  --checksum
         ▼                                        ▼
┌──────────────────────────────────────────────────────┐
│               rclone (--bwlimit 2M)                  │
└─────────────────────────┬────────────────────────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │  Cloudflare R2  │
                 │  (S3 / MinIO)   │
                 └─────────────────┘
```

### Multi-Project Architecture

```
Your Server (walrus)
├── walrus init --mode docker --project shop     # Docker PostgreSQL
├── walrus init --mode direct --project blog     # Local PostgreSQL
├── walrus init --mode direct --project saas     # Remote PostgreSQL
│
└── All backups -> Cloudflare R2
                     backup/
                     ├── shop/
                     │   ├── base/
                     │   └── wal/
                     ├── blog/
                     │   ├── base/
                     │   └── wal/
                     └── saas/
                         ├── base/
                         └── wal/
```

## Performance Impact

walrus is designed to be production-safe:

| Measure | Details |
|---------|---------|
| `--checkpoint=spread` | Spreads checkpoint I/O over time, avoids spikes |
| `--max-rate=30M` | Limits disk read rate, won't saturate your I/O |
| `--bwlimit 2M` | Upload rate limiting, negligible network impact |
| WAL archive (`cp`) | Simple file copy, minimal overhead |

These defaults are safe for databases under heavy read/write load. Adjustable in `lib/constants.sh`.

## Requirements

- Linux or macOS
- Bash 4+
- PostgreSQL 12+ (client tools installed automatically)
- Cloudflare R2 / Amazon S3 / any S3-compatible storage
- **Docker mode**: Docker installed + PostgreSQL container
- **Restore**: Docker required (all modes)
- Root access recommended for systemd integration

## Project Structure

```
walrus/
├── walrus                  # Entry point: module loader + command dispatch
├── install.sh              # Remote one-line installer
├── lib/
│   ├── constants.sh        # Constants & version
│   ├── colors.sh           # Terminal colors (auto-detect)
│   ├── logger.sh           # Logging system
│   ├── cleanup.sh          # Signal handling & temp file cleanup
│   ├── utils.sh            # Interactive prompts & utilities
│   ├── lock.sh             # Concurrency lock
│   ├── project.sh          # Project config management
│   ├── r2.sh               # rclone/R2 operations
│   └── pg.sh               # PostgreSQL abstraction (docker/direct)
├── commands/
│   ├── config.sh           # walrus config
│   ├── init.sh             # walrus init
│   ├── backup.sh           # walrus backup
│   ├── sync.sh             # walrus sync
│   ├── restore.sh          # walrus restore
│   ├── status.sh           # walrus status
│   ├── list.sh             # walrus list
│   ├── logs.sh             # walrus logs
│   ├── service.sh          # walrus service + systemd
│   ├── remove.sh           # walrus remove
│   └── help.sh             # walrus help
├── README.md
├── CONTRIBUTING.md
└── LICENSE
```

## Uninstall

```bash
# Stop and disable services
walrus service disable

# Remove everything
crontab -l 2>/dev/null | grep -v "walrus:" | crontab -
rm -f /usr/local/bin/walrus
rm -rf /opt/walrus
rm -f /etc/systemd/system/walrus-*
systemctl daemon-reload
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and release process.

## Star History

<p align="center">
  <a href="https://star-history.com/#LayFz/walrus&Date">
    <img src="https://api.star-history.com/svg?repos=LayFz/walrus&type=Date" alt="Star History" width="600" />
  </a>
</p>

## License

[MIT](LICENSE)
