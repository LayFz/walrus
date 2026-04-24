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
  简体中文 |
  <a href="./README_TW.md">繁體中文</a> |
  <a href="../README.md">English</a> |
  <a href="./README_JA.md">日本語</a> |
  <a href="./README_FR.md">Français</a>
</p>

---

一条命令备份你所有服务器上的 PostgreSQL 到 Cloudflare R2。多台服务器统一备份，异地容灾随时恢复——再也不用担心数据丢失。

## 为什么选择 walrus？

- **多服务器备份** — 无论你有多少台服务器、多少个数据库，统一备份到一个地方集中管理
- **异地容灾** — 备份存储在远程云端（R2/S3），即使原服务器彻底挂了，也能在任意新机器上恢复
- **时间点恢复** — WAL 归档让你精确恢复到过去 7 天内的任意时刻，而不仅仅是最后一次备份
- **一次配置，永久自动** — 配置一次后完全自动运行：每天全量备份 + 每 5 分钟 WAL 同步

## 特性

- **两种部署模式** — Docker 容器 / 直连数据库 (本地或远程)，统一管理
- **交互式引导** — 问答式配置，不用记参数
- **物理备份** — `pg_basebackup`，不走查询引擎，对业务零影响
- **WAL 增量同步** — 每 5 分钟同步，只传新数据，最多丢 5 分钟
- **带宽限速** — 默认 2MB/s，不影响线上流量
- **多项目管理** — 不同服务器的不同项目，全部归类到一个 R2 bucket
- **自动清理** — 默认保留 7 天，本地和 R2 同步清理
- **一键恢复** — 交互式选择备份点，支持时间点恢复 (PITR)
- **自我更新** — `walrus update` 一键升级，无需重新安装
- **并发安全** — 锁文件防止重复备份

## 第一步：安装

```bash
# 安装最新版
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash
```

安装脚本会自动安装 `postgresql-client` 和 `rclone`（如果尚未安装）。

## 第二步：更新（已有用户）

```bash
# 自我更新到最新版
walrus update
```

更新时会保留现有的项目配置和 rclone 设置。

## 第三步：配置远程存储

```bash
walrus config
```

交互式引导——选择存储服务商（Cloudflare R2、Amazon S3、MinIO 等），输入凭据，walrus 自动验证连接。

## 第四步：注册项目并启动备份

```bash
walrus init
```

`walrus init` 引导你完成：
1. 选择部署模式（Docker / 直连）
2. 输入数据库凭据
3. 配置 WAL 归档
4. 安装 systemd 定时器（每天 03:00 全量备份，每 5 分钟 WAL 同步）
5. 运行端到端测试

`init` 完成后，备份自动运行，无需其他操作。

### 部署模式

**Docker** — PostgreSQL 运行在 Docker 容器中。walrus 在容器内执行 `pg_basebackup`，无需暴露端口。

```bash
walrus init --mode docker \
  --project myapp \
  --container postgres \
  --user myuser --db mydb
```

**直连** — 通过 host:port 直连 PostgreSQL——无论是本机、远程服务器还是托管服务 (RDS)。

```bash
walrus init --mode direct \
  --project myapp \
  --host 10.0.1.5 --port 5432 \
  --user myuser --db mydb
```

> 交互模式下无需记参数，`walrus init` 会一步步引导你。

## 第五步：监控与管理

```bash
# 查看项目状态和服务健康
walrus status

# 查看 R2 上的备份
walrus list

# 查看备份和同步日志
walrus logs

# 实时跟踪日志
walrus logs -f

# 管理 systemd 服务
walrus service status
walrus service stop
walrus service start
```

### 定时服务

| 服务单元 | 说明 | 频率 |
|---------|------|------|
| `walrus-sync@<project>.timer` | WAL 增量同步 | 每 5 分钟 |
| `walrus-backup@<project>.timer` | 全量物理备份 + 清理 | 每天 03:00 |

## 第六步：恢复（从任意机器）

恢复可以在**任何安装了 walrus 和 Docker 的机器**上进行——即使是全新的服务器。只要能连接 R2，就能恢复数据。

```bash
# 在新机器上：安装 walrus 并配置 R2
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash
walrus config

# 交互式恢复（选择备份、输入密码）
walrus restore

# 或恢复到指定时间点
walrus restore --project myapp --password secret \
  --target-time "2026-04-23 14:30:00+08"
```

恢复流程：
1. 从 R2 下载全量备份 + WAL 文件
2. 启动临时 Docker 容器（端口 15432），使用匹配的 PostgreSQL 版本
3. 应用 WAL 回放实现时间点恢复
4. 你验证数据：`docker exec -it walrus_myapp_restore psql -U myuser -d mydb`
5. 确认无误后，迁移数据到生产环境

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
| `walrus update` | 更新 walrus 到最新版本 |
| `walrus help` | 显示帮助 |

> 只注册了一个项目时，`--project` 可省略。命令缩写：`st`=status, `ls`=list, `rm`=remove, `svc`=service

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
                 │  (S3 / MinIO)   │
                 └─────────────────┘
```

### 多项目架构

```
你的服务器 (walrus)
├── walrus init --mode docker --project shop     # Docker PostgreSQL
├── walrus init --mode direct --project blog     # 本地 PostgreSQL
├── walrus init --mode direct --project saas     # 远程 PostgreSQL
│
└── 所有备份 -> Cloudflare R2
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

## 性能影响

walrus 专为生产安全设计：

| 措施 | 详情 |
|------|------|
| `--checkpoint=spread` | 分散 checkpoint I/O，避免瞬间尖峰 |
| `--max-rate=30M` | 限制磁盘读取速率，不会打满 I/O |
| `--bwlimit 2M` | 上传限速，对网络影响可忽略 |
| WAL 归档 (`cp`) | 简单文件拷贝，开销极低 |

以上默认值在高负载读写场景下也是安全的。

## 系统要求

- Linux 或 macOS
- Bash 4+
- PostgreSQL 12+（Docker 模式无需在宿主机安装客户端工具）
- Cloudflare R2 / Amazon S3 / 任何 S3 兼容存储
- **Docker 模式**: 需要安装 Docker
- **恢复功能**: 需要 Docker（所有模式）
- 推荐 root 权限以使用 systemd 集成

## 卸载

```bash
walrus service disable
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
