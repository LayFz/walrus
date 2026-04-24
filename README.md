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
  English |
  <a href="./docs/README_JA.md">日本語</a> |
  <a href="./docs/README_FR.md">Français</a>
</p>

---

One command to back up all your PostgreSQL databases to Cloudflare R2. Back up multiple servers to one place, restore from anywhere — never lose your data again.

## Why walrus?

- **Multi-server backup** — Manage backups from all your servers in one place, no matter how many databases you run
- **Disaster recovery** — Backups stored on remote cloud storage (R2/S3), restore on any machine even if the original server is completely gone
- **Point-in-time recovery** — WAL archiving lets you restore to any moment in the last 7 days, not just the last backup
- **Set it and forget it** — One-time setup, then fully automatic: daily full backups + WAL sync every 5 minutes

## Features

- **Two deployment modes** — Docker container or direct connection (local/remote), unified management
- **Interactive setup** — Step-by-step guided configuration, no need to memorize flags
- **Physical backups** — Uses `pg_basebackup`, bypasses the query engine, zero impact on your app
- **WAL incremental sync** — Every 5 minutes, only transfers new data, max 5 min data loss
- **Bandwidth limiting** — Default 2MB/s upload, won't affect your production traffic
- **Multi-project** — Different databases on different servers, all organized in one R2 bucket
- **Auto-cleanup** — Default 7-day retention, synced cleanup on local and R2
- **One-click restore** — Interactive backup selection with point-in-time recovery (PITR)
- **Self-update** — `walrus update` to upgrade, no need to re-run the installer
- **Concurrency safe** — Lock files prevent duplicate backup operations

## Step 1: Install

```bash
# Install latest version
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash
```

The installer automatically sets up `postgresql-client` and `rclone` if not already present.

## Step 2: Update (existing users)

```bash
# Self-update to the latest version
walrus update
```

Existing project configurations and rclone settings are preserved during updates.

## Step 3: Configure Remote Storage

```bash
walrus config
```

Interactive setup — choose your storage provider (Cloudflare R2, Amazon S3, MinIO, etc.), enter credentials, and walrus verifies the connection automatically.

## Step 4: Register a Project & Start Backup

```bash
walrus init
```

`walrus init` guides you through:
1. Select deployment mode (Docker / Direct connection)
2. Enter database credentials
3. Configure WAL archiving
4. Install systemd timers (auto backup every day at 03:00, WAL sync every 5 min)
5. Run a full end-to-end test

After `init`, backups run automatically. No further action needed.

### Deployment Modes

**Docker** — PostgreSQL runs in a Docker container. walrus executes `pg_basebackup` inside the container, no need to expose ports.

```bash
walrus init --mode docker \
  --project myapp \
  --container postgres \
  --user myuser --db mydb
```

**Direct** — PostgreSQL is accessible via host:port (localhost, remote server, or managed service like RDS).

```bash
walrus init --mode direct \
  --project myapp \
  --host 10.0.1.5 --port 5432 \
  --user myuser --db mydb
```

> In interactive mode you don't need to remember any flags — `walrus init` will walk you through it.

## Step 5: Monitor & Manage

```bash
# Check project status and service health
walrus status

# View backups stored on R2
walrus list

# View backup and sync logs
walrus logs

# Live tail logs
walrus logs -f

# Manage systemd services
walrus service status
walrus service stop
walrus service start
```

### Service Timers

| Unit | Description | Frequency |
|------|-------------|-----------|
| `walrus-sync@<project>.timer` | WAL incremental sync | Every 5 min |
| `walrus-backup@<project>.timer` | Full physical backup + cleanup | Daily 03:00 |

## Step 6: Restore (from any machine)

Restore works on **any machine** with walrus and Docker installed — even a brand new server. As long as you can connect to R2, you can recover your data.

```bash
# On the new machine: install walrus and configure R2
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash
walrus config

# Interactive restore (select backup, enter password)
walrus restore

# Or restore to a specific point in time
walrus restore --project myapp --password secret \
  --target-time "2026-04-23 14:30:00+08"
```

Restore process:
1. Downloads base backup + WAL files from R2
2. Spins up a temporary Docker container (port 15432) with matching PostgreSQL version
3. Applies WAL replay for point-in-time recovery
4. You verify the data: `docker exec -it walrus_myapp_restore psql -U myuser -d mydb`
5. Once confirmed, migrate data to production

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
| `walrus update` | Update walrus to latest version |
| `walrus help` | Show help |

> When only one project is registered, `--project` can be omitted. Aliases: `st`=status, `ls`=list, `rm`=remove, `svc`=service.

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

These defaults are safe for databases under heavy read/write load.

## Requirements

- Linux or macOS
- Bash 4+
- PostgreSQL 12+ (Docker mode: client tools not required on host)
- Cloudflare R2 / Amazon S3 / any S3-compatible storage
- **Docker mode**: Docker installed + PostgreSQL container
- **Restore**: Docker required (all modes)
- Root access recommended for systemd integration

## Uninstall

```bash
walrus service disable
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
