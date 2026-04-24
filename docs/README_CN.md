<p align="center">
  <img src="images/logo.png" alt="walrus" width="200" />
</p>

<h1 align="center">walrus</h1>

<p align="center">
  <strong>独立开发者的 PostgreSQL 备份伙伴</strong>
</p>

<p align="center">
  <a href="https://github.com/LayFz/walrus/releases"><img src="https://img.shields.io/github/v/release/LayFz/walrus?style=flat-square&color=blue" alt="Release" /></a>
  <a href="https://github.com/LayFz/walrus/blob/main/LICENSE"><img src="https://img.shields.io/github/license/LayFz/walrus?style=flat-square" alt="License" /></a>
  <a href="https://github.com/LayFz/walrus/stargazers"><img src="https://img.shields.io/github/stars/LayFz/walrus?style=flat-square" alt="Stars" /></a>
</p>

<p align="center">
  <a href="../README.md">English</a> |
  简体中文 |
  <a href="./README_TW.md">繁體中文</a> |
  <a href="./README_JA.md">日本語</a> |
  <a href="./README_FR.md">Français</a>
</p>

---

一条命令备份你所有服务器上的 PostgreSQL 到 Cloudflare R2。为独立开发者设计——多项目、多服务器、零负担。

## 特性

- **两种部署模式** — Docker 容器 / 直连数据库 (本地或远程)，统一管理
- **交互式引导** — 问答式配置，不用记参数
- **物理备份** — `pg_basebackup`，不走查询引擎，对业务零影响
- **WAL 增量同步** — 每 5 分钟同步，只传新数据，最多丢 5 分钟
- **带宽限速** — 默认 2MB/s，不影响线上流量
- **多项目管理** — 不同服务器的不同项目，全部归类到一个 R2 bucket
- **自动清理** — 默认保留 7 天，本地和 R2 同步清理
- **一键恢复** — 交互式选择备份点，支持时间点恢复 (PITR)
- **systemd 服务** — 注册为系统服务，开机自启
- **并发安全** — 锁文件防止重复备份

## 快速开始

### 安装

```bash
# 安装最新版
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash

# 安装指定版本
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | WALRUS_VERSION=2.0.0 sudo -E bash
```

安装脚本会自动安装 `postgresql-client`（如果尚未安装）。

### 更新

```bash
# 更新到最新版（与安装命令相同）
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash
```

更新时会保留现有的项目配置和 rclone 设置。

### 配置

```bash
# 1. 配置 R2 存储（交互式）
walrus config

# 2. 注册项目（交互式引导）
walrus init

# 3. 确认一切正常
walrus status
```

## 部署模式

### Docker 容器

PostgreSQL 运行在 Docker 中，walrus 通过映射端口连接。

```bash
walrus init --mode docker \
  --project myapp \
  --container postgres \
  --host localhost --port 5432 \
  --user myuser --db mydb
```

### 直连数据库

通过 host:port 直连 PostgreSQL——无论是本机、远程服务器还是托管服务 (RDS)。

```bash
walrus init --mode direct \
  --project myapp \
  --host 10.0.1.5 --port 5432 \
  --user myuser --db mydb
```

> 交互模式下无需记参数，`walrus init` 会一步步引导你。

## 命令一览

| 命令 | 说明 |
|------|------|
| `walrus config` | 配置远程存储 (R2/S3/MinIO) |
| `walrus init` | 注册项目（交互式引导） |
| `walrus backup` | 执行全量备份 |
| `walrus sync` | 同步 WAL 日志 |
| `walrus restore` | 从 R2 恢复数据库 |
| `walrus status` | 查看所有项目状态 |
| `walrus list` | 查看 R2 备份详情 |
| `walrus logs` | 查看日志 (`-f` 实时跟踪) |
| `walrus service` | 管理 systemd 服务 |
| `walrus remove` | 移除项目 |

> 只注册了一个项目时，`--project` 可省略。命令缩写：`st`=status, `ls`=list, `rm`=remove

## 恢复

```bash
# 交互式恢复
walrus restore

# 恢复到指定时间点
walrus restore --project myapp --password secret \
  --target-time "2026-04-23 14:30:00+08"
```

所有恢复都会在本地启动一个 Docker 容器（端口 15432）用于验证，确认无误后再迁移到生产环境。

## 工作原理

```
每天 03:00                              每 5 分钟
┌──────────────────┐                     ┌─────────────────┐
│  pg_basebackup   │                     │  WAL 归档        │
│  (物理全量)      │                     │  (增量同步)      │
└────────┬─────────┘                     └────────┬────────┘
         │                                        │
         │  --max-rate=30M                        │  只传新文件
         │  --checkpoint=spread                   │  --checksum
         ▼                                        ▼
┌──────────────────────────────────────────────────────┐
│               rclone (--bwlimit 2M)                  │
└─────────────────────────┬────────────────────────────┘
                          │
                          ▼
                 ┌─────────────────┐
                 │  Cloudflare R2  │
                 └─────────────────┘
```

## 系统要求

- Linux 或 macOS
- Bash 4+
- PostgreSQL 12+（客户端工具自动安装）
- Cloudflare R2 / Amazon S3 / 任何 S3 兼容存储
- **Docker 模式**: 需要安装 Docker
- **恢复功能**: 需要 Docker（所有模式）
- 推荐 root 权限以使用 systemd 集成

## 卸载

```bash
walrus service disable
crontab -l 2>/dev/null | grep -v "walrus:" | crontab -
rm -f /usr/local/bin/walrus
rm -rf /opt/walrus
rm -f /etc/systemd/system/walrus-*
systemctl daemon-reload
```

## Star History

<p align="center">
  <a href="https://star-history.com/#LayFz/walrus&Date">
    <img src="https://api.star-history.com/svg?repos=LayFz/walrus&type=Date" alt="Star History" width="600" />
  </a>
</p>

## 许可证

[MIT](../LICENSE)
