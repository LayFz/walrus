<p align="center">
  <img src="images/logo.png" alt="walrus" width="200" />
</p>

<h1 align="center">walrus</h1>

<p align="center">
  <strong>インディーハッカーのための PostgreSQL バックアップツール</strong>
</p>

<p align="center">
  <a href="https://github.com/LayFz/walrus/releases"><img src="https://img.shields.io/github/v/release/LayFz/walrus?style=flat-square&color=blue" alt="Release" /></a>
  <a href="https://github.com/LayFz/walrus/blob/main/LICENSE"><img src="https://img.shields.io/github/license/LayFz/walrus?style=flat-square" alt="License" /></a>
  <a href="https://github.com/LayFz/walrus/stargazers"><img src="https://img.shields.io/github/stars/LayFz/walrus?style=flat-square" alt="Stars" /></a>
</p>

<p align="center">
  <a href="./README_CN.md">简体中文</a> |
  <a href="./README_TW.md">繁體中文</a> |
  <a href="../README.md">English</a> |
  日本語 |
  <a href="./README_FR.md">Français</a>
</p>

---

ワンコマンドで全ての PostgreSQL データベースを Cloudflare R2 にバックアップ。複数サーバーを一元管理、どこからでも復旧可能——データ損失の心配はもうありません。

## なぜ walrus？

- **マルチサーバーバックアップ** — サーバーやデータベースの数に関係なく、1箇所で一元管理
- **災害復旧** — バックアップはリモートクラウド（R2/S3）に保存。元のサーバーが完全に失われても、任意のマシンで復旧可能
- **ポイントインタイムリカバリ** — WAL アーカイブにより、直近7日間の任意の時点に精密復元。最後のバックアップだけでなく、任意の瞬間に戻せます
- **設定したら放置でOK** — 一度設定すれば完全自動：毎日フルバックアップ + 5分ごとの WAL 同期

## 特徴

- **2つのデプロイモード** — Docker コンテナ / 直接接続（ローカル・リモート）、統一管理
- **対話式セットアップ** — ステップバイステップのガイド、フラグの暗記不要
- **物理バックアップ** — `pg_basebackup` 使用、クエリエンジンをバイパス、アプリへの影響ゼロ
- **WAL 増分同期** — 5分ごと、新しいデータのみ転送、最大5分のデータロス
- **帯域制限** — デフォルト 2MB/s、本番トラフィックに影響なし
- **マルチプロジェクト** — 異なるサーバーの異なるDBを1つの R2 バケットで管理
- **自動クリーンアップ** — デフォルト7日間保持、ローカルと R2 を同期クリーンアップ
- **ワンクリックリストア** — 対話式バックアップ選択、ポイントインタイムリカバリ (PITR) 対応
- **セルフアップデート** — `walrus update` でアップグレード、再インストール不要
- **並行処理安全** — ロックファイルで重複バックアップを防止

## ステップ 1：インストール

```bash
# 最新版をインストール
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash
```

インストーラーは `postgresql-client` と `rclone` が未インストールの場合、自動でセットアップします。

## ステップ 2：アップデート（既存ユーザー）

```bash
# 最新版にセルフアップデート
walrus update
```

既存のプロジェクト設定と rclone の設定は更新時に保持されます。

## ステップ 3：リモートストレージの設定

```bash
walrus config
```

対話式ガイド — ストレージプロバイダー（Cloudflare R2、Amazon S3、MinIO 等）を選択し、認証情報を入力すると、walrus が自動で接続を検証します。

## ステップ 4：プロジェクト登録とバックアップ開始

```bash
walrus init
```

`walrus init` がガイドする内容：
1. デプロイモードの選択（Docker / 直接接続）
2. データベース認証情報の入力
3. WAL アーカイブの設定
4. systemd タイマーのインストール（毎日 03:00 フルバックアップ、5分ごと WAL 同期）
5. エンドツーエンドテストの実行

`init` 完了後、バックアップは自動実行されます。追加の操作は不要です。

### デプロイモード

**Docker** — PostgreSQL が Docker コンテナで動作。walrus はコンテナ内で `pg_basebackup` を実行、ポートの公開は不要。

```bash
walrus init --mode docker \
  --project myapp \
  --container postgres \
  --user myuser --db mydb
```

**直接接続** — host:port 経由で PostgreSQL に接続（localhost、リモートサーバー、RDS 等のマネージドサービス）。

```bash
walrus init --mode direct \
  --project myapp \
  --host 10.0.1.5 --port 5432 \
  --user myuser --db mydb
```

> 対話モードではフラグを覚える必要はありません — `walrus init` がステップバイステップでガイドします。

## ステップ 5：監視と管理

```bash
# プロジェクトステータスとサービス状態を確認
walrus status

# R2 上のバックアップを表示
walrus list

# バックアップと同期のログを表示
walrus logs

# リアルタイムでログを追跡
walrus logs -f

# systemd サービスの管理
walrus service status
walrus service stop
walrus service start
```

### タイマーサービス

| ユニット | 説明 | 頻度 |
|---------|------|------|
| `walrus-sync@<project>.timer` | WAL 増分同期 | 5分ごと |
| `walrus-backup@<project>.timer` | 物理フルバックアップ + クリーンアップ | 毎日 03:00 |

## ステップ 6：リストア（任意のマシンから）

リストアは **walrus と Docker がインストールされた任意のマシン** で実行可能 — 新しいサーバーでも可能です。R2 に接続できれば、データを復旧できます。

```bash
# 新しいマシンで：walrus をインストールし R2 を設定
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash
walrus config

# 対話式リストア（バックアップを選択、パスワードを入力）
walrus restore

# または特定の時点にリストア
walrus restore --project myapp --password secret \
  --target-time "2026-04-23 14:30:00+08"
```

リストアプロセス：
1. R2 からフルバックアップ + WAL ファイルをダウンロード
2. 一致する PostgreSQL バージョンで一時 Docker コンテナを起動（ポート 15432）
3. WAL リプレイでポイントインタイムリカバリを適用
4. データを検証：`docker exec -it walrus_myapp_restore psql -U myuser -d mydb`
5. 確認後、本番環境にデータを移行

## コマンド一覧

| コマンド | 説明 |
|---------|------|
| `walrus config` | リモートストレージの設定 (R2/S3/MinIO) |
| `walrus init` | プロジェクトの対話式登録 |
| `walrus backup` | フルバックアップの実行 |
| `walrus sync` | WAL ログの同期 |
| `walrus restore` | R2 からデータベースをリストア |
| `walrus status` | 全プロジェクトのステータス表示 |
| `walrus list` | R2 バックアップの詳細表示 |
| `walrus logs` | ログ表示 (`-f` でリアルタイム追跡) |
| `walrus service` | systemd サービスの管理 |
| `walrus remove` | プロジェクトの削除 |
| `walrus update` | walrus を最新版に更新 |
| `walrus help` | ヘルプの表示 |

> プロジェクトが1つだけ登録されている場合、`--project` は省略可能。エイリアス：`st`=status, `ls`=list, `rm`=remove, `svc`=service

## 仕組み

```
毎日 03:00                              5分ごと
┌──────────────────┐                     ┌─────────────────┐
│  pg_basebackup   │                     │  WAL アーカイブ   │
│  (物理フル)      │                     │  (増分同期)      │
└────────┬─────────┘                     └────────┬────────┘
         │                                        │
         │  --max-rate=30M                        │  新しいファイルのみ
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

### マルチプロジェクトアーキテクチャ

```
あなたのサーバー (walrus)
├── walrus init --mode docker --project shop     # Docker PostgreSQL
├── walrus init --mode direct --project blog     # ローカル PostgreSQL
├── walrus init --mode direct --project saas     # リモート PostgreSQL
│
└── 全バックアップ -> Cloudflare R2
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

## パフォーマンスへの影響

walrus は本番環境での安全性を重視して設計されています：

| 対策 | 詳細 |
|------|------|
| `--checkpoint=spread` | checkpoint I/O を分散、スパイクを回避 |
| `--max-rate=30M` | ディスク読み取り速度を制限、I/O を圧迫しない |
| `--bwlimit 2M` | アップロード速度制限、ネットワークへの影響は無視できるレベル |
| WAL アーカイブ (`cp`) | シンプルなファイルコピー、オーバーヘッド最小 |

これらのデフォルト値は高負荷な読み書きワークロードでも安全です。

## システム要件

- Linux または macOS
- Bash 4+
- PostgreSQL 12+（Docker モードではホストにクライアントツール不要）
- Cloudflare R2 / Amazon S3 / 任意の S3 互換ストレージ
- **Docker モード**: Docker のインストールが必要
- **リストア**: Docker が必要（全モード）
- systemd 統合には root 権限を推奨

## アンインストール

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

## ライセンス

[MIT](../LICENSE)
