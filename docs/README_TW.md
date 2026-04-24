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
  <a href="./README_CN.md">简体中文</a> |
  繁體中文 |
  <a href="../README.md">English</a> |
  <a href="./README_JA.md">日本語</a> |
  <a href="./README_FR.md">Français</a>
</p>

---

一條指令備份你所有伺服器上的 PostgreSQL 到 Cloudflare R2。多台伺服器統一備份，異地容災隨時還原——再也不用擔心資料遺失。

## 為什麼選擇 walrus？

- **多伺服器備份** — 無論你有多少台伺服器、多少個資料庫，統一備份到一個地方集中管理
- **異地容災** — 備份儲存在遠端雲端（R2/S3），即使原伺服器徹底掛了，也能在任意新機器上還原
- **時間點還原** — WAL 歸檔讓你精確還原到過去 7 天內的任意時刻，而不僅僅是最後一次備份
- **一次設定，永久自動** — 設定一次後完全自動執行：每天全量備份 + 每 5 分鐘 WAL 同步

## 特色

- **兩種部署模式** — Docker 容器 / 直連資料庫（本機或遠端），統一管理
- **互動式引導** — 問答式設定，不用記參數
- **實體備份** — `pg_basebackup`，不經查詢引擎，對業務零影響
- **WAL 增量同步** — 每 5 分鐘同步，只傳新資料，最多遺失 5 分鐘
- **頻寬限速** — 預設 2MB/s，不影響線上流量
- **多專案管理** — 不同伺服器的不同專案，全部歸類到一個 R2 bucket
- **自動清理** — 預設保留 7 天，本機和 R2 同步清理
- **一鍵還原** — 互動式選擇備份點，支援時間點還原 (PITR)
- **自我更新** — `walrus update` 一鍵升級，無需重新安裝
- **並行安全** — 鎖定檔案防止重複備份

## 第一步：安裝

```bash
# 安裝最新版
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash
```

安裝腳本會自動安裝 `postgresql-client` 和 `rclone`（若尚未安裝）。

## 第二步：更新（已有使用者）

```bash
# 自我更新至最新版
walrus update
```

更新時會保留現有的專案設定和 rclone 配置。

## 第三步：設定遠端儲存

```bash
walrus config
```

互動式引導——選擇儲存服務商（Cloudflare R2、Amazon S3、MinIO 等），輸入憑據，walrus 自動驗證連線。

## 第四步：註冊專案並啟動備份

```bash
walrus init
```

`walrus init` 引導你完成：
1. 選擇部署模式（Docker / 直連）
2. 輸入資料庫憑據
3. 設定 WAL 歸檔
4. 安裝 systemd 定時器（每天 03:00 全量備份，每 5 分鐘 WAL 同步）
5. 執行端對端測試

`init` 完成後，備份自動執行，無需其他操作。

### 部署模式

**Docker** — PostgreSQL 執行在 Docker 容器中。walrus 在容器內執行 `pg_basebackup`，無需暴露埠。

```bash
walrus init --mode docker \
  --project myapp \
  --container postgres \
  --user myuser --db mydb
```

**直連** — 透過 host:port 直連 PostgreSQL——無論是本機、遠端伺服器還是託管服務 (RDS)。

```bash
walrus init --mode direct \
  --project myapp \
  --host 10.0.1.5 --port 5432 \
  --user myuser --db mydb
```

> 互動模式下無需記參數，`walrus init` 會逐步引導你。

## 第五步：監控與管理

```bash
# 檢視專案狀態和服務健康
walrus status

# 檢視 R2 上的備份
walrus list

# 檢視備份和同步日誌
walrus logs

# 即時追蹤日誌
walrus logs -f

# 管理 systemd 服務
walrus service status
walrus service stop
walrus service start
```

### 定時服務

| 服務單元 | 說明 | 頻率 |
|---------|------|------|
| `walrus-sync@<project>.timer` | WAL 增量同步 | 每 5 分鐘 |
| `walrus-backup@<project>.timer` | 全量實體備份 + 清理 | 每天 03:00 |

## 第六步：還原（從任意機器）

還原可以在**任何安裝了 walrus 和 Docker 的機器**上進行——即使是全新的伺服器。只要能連線 R2，就能還原資料。

```bash
# 在新機器上：安裝 walrus 並設定 R2
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash
walrus config

# 互動式還原（選擇備份、輸入密碼）
walrus restore

# 或還原到指定時間點
walrus restore --project myapp --password secret \
  --target-time "2026-04-23 14:30:00+08"
```

還原流程：
1. 從 R2 下載全量備份 + WAL 檔案
2. 啟動臨時 Docker 容器（埠 15432），使用匹配的 PostgreSQL 版本
3. 套用 WAL 回放實現時間點還原
4. 你驗證資料：`docker exec -it walrus_myapp_restore psql -U myuser -d mydb`
5. 確認無誤後，遷移資料到正式環境

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
| `walrus update` | 更新 walrus 至最新版本 |
| `walrus help` | 顯示說明 |

> 只註冊了一個專案時，`--project` 可省略。指令縮寫：`st`=status, `ls`=list, `rm`=remove, `svc`=service

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
                 │  (S3 / MinIO)   │
                 └─────────────────┘
```

### 多專案架構

```
你的伺服器 (walrus)
├── walrus init --mode docker --project shop     # Docker PostgreSQL
├── walrus init --mode direct --project blog     # 本機 PostgreSQL
├── walrus init --mode direct --project saas     # 遠端 PostgreSQL
│
└── 所有備份 -> Cloudflare R2
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

## 性能影響

walrus 專為生產安全設計：

| 措施 | 詳情 |
|------|------|
| `--checkpoint=spread` | 分散 checkpoint I/O，避免瞬間尖峰 |
| `--max-rate=30M` | 限制磁碟讀取速率，不會打滿 I/O |
| `--bwlimit 2M` | 上傳限速，對網路影響可忽略 |
| WAL 歸檔 (`cp`) | 簡單檔案複製，開銷極低 |

以上預設值在高負載讀寫場景下也是安全的。

## 系統需求

- Linux 或 macOS
- Bash 4+
- PostgreSQL 12+（Docker 模式無需在宿主機安裝用戶端工具）
- Cloudflare R2 / Amazon S3 / 任何 S3 相容儲存
- **Docker 模式**: 需要安裝 Docker
- **還原功能**: 需要 Docker（所有模式）
- 建議以 root 權限執行以使用 systemd 整合

## 解除安裝

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

## 授權條款

[MIT](../LICENSE)
