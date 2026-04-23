<p align="center">
  <img src="images/logo.png" alt="walrus" width="200" />
</p>

<h1 align="center">walrus</h1>

<p align="center">
  <strong>獨立開發者的 PostgreSQL 備份夥伴</strong>
</p>

<p align="center">
  <a href="https://github.com/LayFz/walrus/releases"><img src="https://img.shields.io/github/v/release/LayFz/walrus?style=flat-square&color=blue" alt="Release" /></a>
  <a href="https://github.com/LayFz/walrus/blob/main/LICENSE"><img src="https://img.shields.io/github/license/LayFz/walrus?style=flat-square" alt="License" /></a>
  <a href="https://github.com/LayFz/walrus/stargazers"><img src="https://img.shields.io/github/stars/LayFz/walrus?style=flat-square" alt="Stars" /></a>
</p>

<p align="center">
  <a href="../README.md">English</a> |
  <a href="./README_CN.md">简体中文</a> |
  繁體中文 |
  <a href="./README_JA.md">日本語</a> |
  <a href="./README_FR.md">Français</a>
</p>

---

一條指令備份你所有伺服器上的 PostgreSQL 到 Cloudflare R2。為獨立開發者設計——多專案、多伺服器、零負擔。

## 特色

- **兩種部署模式** — Docker 容器 / 直連資料庫（本機或遠端），統一管理
- **互動式引導** — 問答式設定，不用記參數
- **實體備份** — `pg_basebackup`，不經查詢引擎，對業務零影響
- **WAL 增量同步** — 每 5 分鐘同步，只傳新資料，最多遺失 5 分鐘
- **頻寬限速** — 預設 2MB/s，不影響線上流量
- **多專案管理** — 不同伺服器的不同專案，全部歸類到一個 R2 bucket
- **自動清理** — 預設保留 7 天，本機和 R2 同步清理
- **一鍵還原** — 互動式選擇備份點，支援時間點還原 (PITR)
- **systemd 服務** — 註冊為系統服務，開機自啟
- **並行安全** — 鎖定檔案防止重複備份

## 快速開始

### 安裝

```bash
# 安裝最新版
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash

# 安裝指定版本
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | WALRUS_VERSION=2.0.0 sudo -E bash
```

安裝腳本會自動安裝 `postgresql-client`（若尚未安裝）。

### 設定

```bash
# 1. 設定 R2 儲存（互動式）
walrus config

# 2. 註冊專案（互動式引導）
walrus init

# 3. 確認一切正常
walrus status
```

## 部署模式

### Docker 容器

PostgreSQL 執行在 Docker 中，walrus 透過映射埠連線。

```bash
walrus init --mode docker \
  --project myapp \
  --container postgres \
  --host localhost --port 5432 \
  --user myuser --db mydb
```

### 直連資料庫

透過 host:port 直連 PostgreSQL——無論是本機、遠端伺服器還是託管服務 (RDS)。

```bash
walrus init --mode direct \
  --project myapp \
  --host 10.0.1.5 --port 5432 \
  --user myuser --db mydb
```

> 互動模式下無需記參數，`walrus init` 會逐步引導你。

## 指令一覽

| 指令 | 說明 |
|------|------|
| `walrus config` | 設定遠端儲存 (R2/S3/MinIO) |
| `walrus init` | 註冊專案（互動式引導） |
| `walrus backup` | 執行全量備份 |
| `walrus sync` | 同步 WAL 日誌 |
| `walrus restore` | 從 R2 還原資料庫 |
| `walrus status` | 檢視所有專案狀態 |
| `walrus list` | 檢視 R2 備份詳情 |
| `walrus logs` | 檢視日誌 (`-f` 即時追蹤) |
| `walrus service` | 管理 systemd 服務 |
| `walrus remove` | 移除專案 |

> 只註冊了一個專案時，`--project` 可省略。指令縮寫：`st`=status, `ls`=list, `rm`=remove

## 還原

```bash
# 互動式還原
walrus restore

# 還原到指定時間點
walrus restore --project myapp --password secret \
  --target-time "2026-04-23 14:30:00+08"
```

所有還原都會在本機啟動一個 Docker 容器（埠 15432）用於驗證，確認無誤後再遷移到正式環境。

## 運作原理

```
每天 03:00                              每 5 分鐘
┌──────────────────┐                     ┌─────────────────┐
│  pg_basebackup   │                     │  WAL 歸檔        │
│  (實體全量)      │                     │  (增量同步)      │
└────────┬─────────┘                     └────────┬────────┘
         │                                        │
         │  --max-rate=30M                        │  只傳新檔案
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

## 系統需求

- Linux 或 macOS
- Bash 4+
- PostgreSQL 12+（用戶端工具自動安裝）
- Cloudflare R2 / Amazon S3 / 任何 S3 相容儲存
- **Docker 模式**: 需要安裝 Docker
- **還原功能**: 需要 Docker（所有模式）
- 建議以 root 權限執行以使用 systemd 整合

## 解除安裝

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

## 授權條款

[MIT](../LICENSE)
