# 🦭 walrus

> PostgreSQL backup buddy for indie hackers

一条命令备份你所有服务器上的 PostgreSQL 到 Cloudflare R2。为独立开发者设计——多项目、多服务器、零负担。

## Features

- **交互式引导** — 像 rclone 一样，问答式配置，不用记参数
- **物理备份** — `pg_basebackup`，不走查询引擎，对业务零影响
- **WAL 增量同步** — 每 5 分钟同步，只传新数据，最多丢 5 分钟
- **带宽限速** — 默认 2MB/s，全球业务不受影响
- **多项目管理** — 不同服务器的不同项目，全部归类到一个 R2 bucket
- **自动清理** — 默认保留 7 天，本地和 R2 同步清理
- **一键恢复** — 交互式选择备份点，支持 point-in-time recovery
- **systemd 服务** — 注册为系统服务，开机自启，像装 MySQL 一样
- **并发安全** — 锁文件防止重复备份
- **信号处理** — Ctrl+C 安全退出，临时文件自动清理

## Quick Start

### Install

```bash
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash
```

### Setup

```bash
# 1. 配置 R2 存储（交互式）
walrus config

# 2. 注册项目（交互式引导，自动检测 PG 容器）
walrus init

# 3. 确认一切正常
walrus status
```

就这样。walrus 会自动检测你的 PostgreSQL 容器、配置 WAL 归档、注册 systemd 服务、跑一次完整测试。

### One-liner (CI/脚本场景)

```bash
walrus init \
  --project myapp \
  --container postgres \
  --user myuser \
  --db mydb \
  --r2-access-key <KEY> \
  --r2-secret-key <SECRET> \
  --r2-endpoint https://xxxx.r2.cloudflarestorage.com
```

## Commands

```
walrus config     配置 R2 存储连接
walrus init       注册项目并配置自动备份
walrus backup     立即执行全量备份
walrus sync       立即同步 WAL 日志
walrus restore    从 R2 恢复数据库
walrus status     查看所有项目状态
walrus list       查看 R2 上的备份详情
walrus logs       查看日志 (支持 -f 实时跟踪)
walrus service    管��系统服��� (start|stop|status|enable|disable)
walrus remove     移除项目
walrus help       帮助
```

> 只注册了一个项目时，`--project` 可以省略。命令缩写：`st`=status, `ls`=list, `rm`=remove, `svc`=service

## Service Management

walrus 会为每个项目注册两个 systemd timer，像装 MySQL 一样作为系统服务运行：

```bash
# 查看服务状态
walrus service status

# 输出示例:
#   masous
#     WAL 同步:  ● 活跃 → 下次: 2 min left
#     全量备份:  ● 活跃 → 下次: Thu 2026-04-23 03:00:00 CST

# 停止/启动
walrus service stop
walrus service start

# 禁用开机自启
walrus service disable
```

每个���目对应两个 systemd 单元：

| Unit | 说明 | 频率 |
|------|------|------|
| `walrus-sync@<project>.timer` | WAL 增量同步 | 每 5 分钟 |
| `walrus-backup@<project>.timer` | 全量物理备份 + 清理 | 每天 03:00 |

同时保留 cron 作为后备（无 systemd 的环境自动降级）。

## Multi-server Usage

walrus 为多服务器场景设计。在每台服务器上安装后注册各自的项目：

```
Server A (电商)          Server B (博客)          Server C (SaaS)
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│ walrus init       │    │ walrus init       │    │ walrus init       │
│  --project shop   │    │  --project blog   │    │  --project saas   │
└────────┬─────────┘    └────────┬─────────┘    └────────┬─────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │    Cloudflare R2         │
                    │                         │
                    │  backup/                │
                    │  ├── shop/              │
                    │  │   ├── base/          │
                    │  │   └── wal/           │
                    │  ├── blog/              │
                    │  │   ├── base/          │
                    │  │   └── wal/           │
                    │  └── saas/              │
                    │      ├── base/          │
                    │      └── wal/           │
                    └─────────────────────────┘
```

## Restore

```bash
# 交互式恢复（选择备份、输入密码）
walrus restore

# 恢复到指定时间点
walrus restore --project myapp --password secret \
  --target-time "2026-04-22 14:30:00+08"
```

恢复后的数据库运行在端口 15432，验证无误后切换即可。

## Project Structure

```
walrus/
├── walrus                  # 入口：加载模块 + 命令分发
├── install.sh              # 远程一键安装
├── lib/
│   ├── constants.sh        # 常量 & 版本
│   ├── colors.sh           # 终端颜色（自动检测）
│   ├── logger.sh           # 日志系统
│   ├── cleanup.sh          # 信号处理 & 临时文件清理
│   ├── utils.sh            # 交互提示 & 通用工具
│   ├── lock.sh             # 并发锁
│   ├── project.sh          # 项目配置管理
│   └── r2.sh               # rclone/R2 操作封装
├── commands/
│   ├── config.sh           # walrus config
│   ├── init.sh             # walrus init
│   ├── backup.sh           # walrus backup
│   ├── sync.sh             # walrus sync
│   ├── restore.sh          # walrus restore
│   ├── status.sh           # walrus status
│   ├── list.sh             # walrus list
│   ├── logs.sh             # walrus logs
│   ├── service.sh          # walrus service + systemd 管理
│   ├── remove.sh           # walrus remove
│   └── help.sh             # walrus help
├── README.md
└── LICENSE
```

安装后的服务器目录：

```
/opt/walrus/
├── walrus                  # 主程序
├── lib/                    # 库文件
├── commands/               # 命令文件
├── conf/
│   ├── .default_bucket     # 默认 bucket
│   ├── myapp.conf          # 项目配置
│   └── blog.conf
├── data/
│   ├── base/<project>/     # 本地 base backup
│   └── wal/<project>/      # 本地 WAL 缓存
├── logs/<project>/         # 日志
└── locks/<project>/        # 运行锁
```

## How It Works

```
每天 03:00                            每 5 分钟
┌─��───────────┐                     ┌───────────┐
│ pg_basebackup│                     │ WAL 归档   │
│ (物理全量)   │                     │ (增量同步) │
└──────┬──────┘                     └─────┬─────┘
       │                                  │
       │  --max-rate=30M                  │  只传新文件
       │  --checkpoint=spread             │  --checksum
       ▼                                  ▼
┌─────���────────────────────────────────────────┐
│              rclone (--bwlimit 2M)           │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
              ┌─────────────────┐
              │  Cloudflare R2  │
              └─────────────────┘
```

## Performance

| Operation | DB Impact | Bandwidth |
|-----------|-----------|-----------|
| WAL archiving (container internal cp) | None | None |
| WAL upload (rclone) | None | ≤ 2MB/s |
| pg_basebackup | Disk read, rate-limited 30MB/s | None |
| Base backup upload | None | ≤ 2MB/s |

## Requirements

- Linux (Ubuntu/Debian/CentOS)
- Docker
- PostgreSQL 12+ in Docker
- Bash 4+
- Root access
- Cloudflare R2 account

## Uninstall

```bash
# Stop services
walrus service disable

# Remove everything
crontab -l 2>/dev/null | grep -v "walrus:" | crontab -
rm -f /usr/local/bin/walrus
rm -rf /opt/walrus
rm -f /etc/systemd/system/walrus-*
systemctl daemon-reload
```

## License

MIT
