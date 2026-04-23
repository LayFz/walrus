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
  <a href="../README.md">English</a> |
  <a href="./README_CN.md">简体中文</a> |
  <a href="./README_TW.md">繁體中文</a> |
  日本語 |
  <a href="./README_FR.md">Français</a>
</p>

---

1つのコマンドで、すべてのサーバーの PostgreSQL を Cloudflare R2 にバックアップ。インディーハッカー向けに設計——マルチプロジェクト、マルチサーバー、手間ゼロ。

## 特徴

- **2つのデプロイモード** — Docker コンテナ / 直接接続（ローカルまたはリモート）、統一管理
- **対話式セットアップ** — 質問に答えるだけで設定完了、フラグを覚える必要なし
- **物理バックアップ** — `pg_basebackup` を使用、クエリエンジンを経由せず、アプリへの影響ゼロ
- **WAL 増分同期** — 5分ごとに同期、新しいデータのみ転送、最大5分のデータ損失
- **帯域制限** — デフォルト 2MB/s アップロード、本番トラフィックに影響なし
- **マルチプロジェクト** — 異なるサーバーの異なるデータベースを1つの R2 バケットに整理
- **自動クリーンアップ** — デフォルト7日間保持、ローカルと R2 を同期クリーンアップ
- **ワンクリック復元** — 対話式バックアップ選択、ポイントインタイムリカバリ (PITR) 対応
- **systemd 統合** — システムサービスとして登録、起動時に自動開始
- **並行処理安全** — ロックファイルで重複バックアップを防止

## クイックスタート

### インストール

```bash
# 最新版をインストール
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | sudo bash

# 特定バージョンをインストール
curl -sSL https://raw.githubusercontent.com/LayFz/walrus/main/install.sh | WALRUS_VERSION=2.0.0 sudo -E bash
```

インストーラーは `postgresql-client` が未インストールの場合、自動でセットアップします。

### セットアップ

```bash
# 1. R2 ストレージを設定（対話式）
walrus config

# 2. プロジェクトを登録（対話式ガイド）
walrus init

# 3. すべてが正常に動作しているか確認
walrus status
```

## デプロイモード

### Docker コンテナ

PostgreSQL が Docker で動作している場合。walrus はマッピングされたポート経由で接続します。

```bash
walrus init --mode docker \
  --project myapp \
  --container postgres \
  --host localhost --port 5432 \
  --user myuser --db mydb
```

### 直接接続

host:port で PostgreSQL にアクセス可能な場合——ローカルホスト、リモートサーバー、RDS などのマネージドサービスに対応。

```bash
walrus init --mode direct \
  --project myapp \
  --host 10.0.1.5 --port 5432 \
  --user myuser --db mydb
```

> 対話モードではフラグを覚える必要はありません。`walrus init` がステップバイステップでガイドします。

## コマンド一覧

| コマンド | 説明 |
|---------|------|
| `walrus config` | リモートストレージを設定 (R2/S3/MinIO) |
| `walrus init` | プロジェクトを対話式で登録 |
| `walrus backup` | フルバックアップを実行 |
| `walrus sync` | WAL ログを同期 |
| `walrus restore` | R2 からデータベースを復元 |
| `walrus status` | 全プロジェクトの状態を表示 |
| `walrus list` | R2 のバックアップ詳細を表示 |
| `walrus logs` | ログを表示 (`-f` でリアルタイム追跡) |
| `walrus service` | systemd サービスを管理 |
| `walrus remove` | プロジェクトを削除 |

> プロジェクトが1つだけ登録されている場合、`--project` は省略可能。エイリアス：`st`=status, `ls`=list, `rm`=remove

## 復元

```bash
# 対話式復元
walrus restore

# 特定の時点に復元
walrus restore --project myapp --password secret \
  --target-time "2026-04-23 14:30:00+08"
```

すべての復元はローカルの Docker コンテナ（ポート 15432）で検証用に起動されます。確認後、本番環境にデータを移行できます。

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
                 └─────────────────┘
```

## システム要件

- Linux または macOS
- Bash 4+
- PostgreSQL 12+（クライアントツールは自動インストール）
- Cloudflare R2 / Amazon S3 / 任意の S3 互換ストレージ
- **Docker モード**: Docker のインストールが必要
- **復元機能**: Docker が必要（全モード）
- systemd 統合のために root 権限を推奨

## アンインストール

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

## ライセンス

[MIT](../LICENSE)
