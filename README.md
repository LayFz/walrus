# 🦭 walrus

PostgreSQL backup buddy for indie hackers.

一条命令备份你所有服务器上的 PostgreSQL 数据库到 Cloudflare R2。

## Why walrus?

独立开发者通常有多个项目跑在不同服务器上，每台都有自己的 PostgreSQL。数据库放在单台机器上很不靠谱，但搞一套复杂的备份方案又太费时间。

walrus 帮你搞定这件事：

- **物理备份**，不走查询引擎，对线上业务零影响
- **WAL 增量同步**，每 5 分钟一次，只传新数据，不浪费带宽
- **带宽限速**，全球业务也不怕，默认 2MB/s 不影响用户
- **多项目管理**，一个命令注册新项目，互不干扰
- **7 天自动清理**，R2 本身就便宜，再加上自动清理几乎零成本
- **一键恢复**，新服务器拉下来就能跑，支持恢复到指定时间点

## Quick Start

### 安装

```bash
curl -sSL https://raw.githubusercontent.com/layfz/walrus/main/install.sh | sudo bash
```

### 注册项目

```bash
walrus init \
  --project myapp \
  --container postgres \
  --user myuser \
  --db mydb \
  --r2-access-key <YOUR_KEY> \
  --r2-secret-key <YOUR_SECRET> \
  --r2-endpoint https://xxxx.r2.cloudflarestorage.com
```

搞定。walrus 会自动：
1. 检测环境（Docker、数据库连接、rclone）
2. 配置 WAL 归档
3. 设置定时任务
4. 跑一次完整测试

### 在另一台服务器添加项目

```bash
# 安装 walrus
curl -sSL https://raw.githubusercontent.com/layfz/walrus/main/install.sh | sudo bash

# 注册这台机器上的项目
walrus init \
  --project another-app \
  --container pg_another \
  --user admin \
  --db another_db \
  --r2-access-key <KEY> \
  --r2-secret-key <SECRET> \
  --r2-endpoint <ENDPOINT>
```

所有项目的备份都会按名称归类到同一个 R2 bucket。

## Commands

```
walrus init      注册新项目并配置自动备份
walrus backup    立即执行全量备份
walrus sync      立即同步 WAL 日志
walrus restore   从 R2 恢复数据库
walrus status    查看所有项目状态
walrus logs      查看项目日志
walrus remove    移除项目（保留 R2 备份）
walrus help      帮助
```

### walrus init

```bash
walrus init \
  --project <项目名>     \   # 必填
  --container <容器名>   \   # 必填
  --user <数据库用户>    \   # 必填
  --db <数据库名>        \   # 必填
  --r2-access-key <key>  \   # 首次必填
  --r2-secret-key <key>  \   # 首次必填
  --r2-endpoint <url>    \   # 首次必填
  --bwlimit 2M           \   # 可选，默认 2MB/s
  --keep 7               \   # 可选，保留天数，默认 7
  --bucket backup             # 可选，R2 bucket 名，默认 backup
```

### walrus backup

```bash
walrus backup --project myapp
```

执行一次全量物理备份（pg_basebackup），上传到 R2，并清理过期备份。

### walrus sync

```bash
walrus sync --project myapp
```

同步 WAL 日志到 R2。自动任务每 5 分钟执行一次，也可手动触发。

### walrus restore

```bash
# 恢复到最新
walrus restore --project myapp --password secret123

# 恢复到指定时间点
walrus restore --project myapp --password secret123 \
  --target-time "2026-04-22 14:30:00+08"
```

恢复后的数据库运行在端口 `15432`，避免与现有服务冲突。

### walrus status

```bash
walrus status
```

查看所有已注册项目的状态，包括容器状态、备份数量、最新备份时间等。

### walrus logs

```bash
walrus logs --project myapp
```

### walrus remove

```bash
walrus remove --project myapp
```

移除本地配置和数据，R2 上的备份会保留。

## R2 Directory Structure

```
backup/
├── myapp/
│   ├── base/
│   │   ├── base_20260422_030000.tar.gz
│   │   └── base_20260423_030000.tar.gz
│   └── wal/
│       ├── 000000010000000000000001
│       └── ...
├── another-app/
│   ├── base/
│   └── wal/
```

## Performance Impact

| Operation | Database Impact | Bandwidth |
|-----------|----------------|-----------|
| WAL archiving (local cp) | None | None |
| WAL upload (rclone) | None | ≤ 2MB/s |
| pg_basebackup | Disk read, rate-limited to 30MB/s | None (local first) |
| Base backup upload | None | ≤ 2MB/s |

## Requirements

- Linux (Ubuntu/Debian/CentOS)
- Docker
- PostgreSQL 12+ (running in Docker)
- Root access
- Cloudflare R2 account

## Uninstall

```bash
# Remove cron jobs
crontab -l | grep -v "walrus:" | crontab -

# Remove walrus
rm -f /usr/local/bin/walrus
rm -rf /opt/walrus
```

## License

MIT
