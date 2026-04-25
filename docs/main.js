// ── i18n translations ──
const i18n = {
  en: {
    "hero.title": "walrus",
    "hero.tagline": "PostgreSQL backup buddy for indie hackers",
    "hero.desc": "One command to back up all your PostgreSQL databases to Cloudflare R2. Multi-server, disaster recovery, zero hassle.",
    "hero.copy": "Copy",
    "hero.releases": "Releases",
    "why.title": "Why walrus?",
    "why.multi.title": "Multi-Server Backup",
    "why.multi.desc": "Manage backups from all your servers in one place, no matter how many databases you run.",
    "why.disaster.title": "Disaster Recovery",
    "why.disaster.desc": "Backups stored on remote cloud storage. Restore on any machine even if the original server is completely gone.",
    "why.pitr.title": "Point-in-Time Recovery",
    "why.pitr.desc": "Restore to any moment in the last 7 days, not just the last backup. WAL archiving every 5 minutes.",
    "why.auto.title": "Set It and Forget It",
    "why.auto.desc": "One-time setup, then fully automatic. Daily full backups + WAL sync every 5 minutes.",
    "steps.title": "How It Works",
    "steps.s1.title": "Install",
    "steps.s2.title": "Configure Storage",
    "steps.s3.title": "Register Project",
    "steps.s4.title": "Auto Backup",
    "steps.s4.desc": "Daily 03:00 + WAL every 5 min",
    "steps.s5.title": "Monitor",
    "steps.s6.title": "Restore Anywhere",
    "features.title": "Features",
    "features.modes": "Two deployment modes, unified management",
    "features.physical": "Physical backups, zero impact on your app",
    "features.wal": "Incremental sync every 5 minutes",
    "features.bwlimit": "Bandwidth limiting, won't affect production",
    "features.storage": "Cloudflare R2, Amazon S3, MinIO, any S3-compatible",
    "features.systemd": "Runs as system service, starts on boot",
    "features.lightweight": "Pure Bash, no dependencies, ultra lightweight",
    "features.update": "Self-update, no need to re-install",
    "commands.title": "Commands",
    "commands.config": "Configure remote storage",
    "commands.init": "Register a project (interactive)",
    "commands.backup": "Run a full physical backup",
    "commands.sync": "Sync WAL logs to R2",
    "commands.restore": "Restore database from R2",
    "commands.status": "Show project status",
    "commands.list": "Show R2 backup details",
    "commands.logs": "View logs (-f for live tail)",
    "commands.update": "Update to latest version",
    "arch.title": "Architecture",
    "footer.releases": "Releases",
    "footer.issues": "Issues"
  },
  zh: {
    "hero.title": "walrus",
    "hero.tagline": "独立开发者的 PostgreSQL 备份伙伴",
    "hero.desc": "一条命令备份你所有服务器上的 PostgreSQL 到 Cloudflare R2。多服务器统一备份，异地容灾，零负担。",
    "hero.copy": "复制",
    "hero.releases": "版本发布",
    "why.title": "为什么选择 walrus？",
    "why.multi.title": "多服务器备份",
    "why.multi.desc": "无论你有多少台服务器、多少个数据库，统一备份到一个地方集中管理。",
    "why.disaster.title": "异地容灾",
    "why.disaster.desc": "备份存储在远程云端，即使原服务器彻底挂了，也能在任意新机器上恢复。",
    "why.pitr.title": "时间点恢复",
    "why.pitr.desc": "精确恢复到过去 7 天内的任意时刻，而不仅仅是最后一次备份。每 5 分钟 WAL 归档。",
    "why.auto.title": "一次配置，永久自动",
    "why.auto.desc": "配置一次后完全自动运行：每天全量备份 + 每 5 分钟 WAL 同步。",
    "steps.title": "工作流程",
    "steps.s1.title": "安装",
    "steps.s2.title": "配置存储",
    "steps.s3.title": "注册项目",
    "steps.s4.title": "自动备份",
    "steps.s4.desc": "每天 03:00 + 每 5 分钟 WAL",
    "steps.s5.title": "监控",
    "steps.s6.title": "随时恢复",
    "features.title": "特性",
    "features.modes": "Docker / 直连两种模式，统一管理",
    "features.physical": "物理备份，对业务零影响",
    "features.wal": "每 5 分钟增量同步",
    "features.bwlimit": "带宽限速，不影响线上流量",
    "features.storage": "Cloudflare R2、Amazon S3、MinIO 等 S3 兼容存储",
    "features.systemd": "系统服务，开机自启",
    "features.lightweight": "纯 Bash，无依赖，超轻量",
    "features.update": "自我更新，无需重新安装",
    "commands.title": "命令一览",
    "commands.config": "配置远程存储",
    "commands.init": "注册项目（交互式）",
    "commands.backup": "执行全量备份",
    "commands.sync": "同步 WAL 日志",
    "commands.restore": "从 R2 恢复数据库",
    "commands.status": "查看项目状态",
    "commands.list": "查看 R2 备份详情",
    "commands.logs": "查看日志（-f 实时跟踪）",
    "commands.update": "更新到最新版本",
    "arch.title": "架构",
    "footer.releases": "版本发布",
    "footer.issues": "问题反馈"
  },
  tw: {
    "hero.title": "walrus",
    "hero.tagline": "獨立開發者的 PostgreSQL 備份夥伴",
    "hero.desc": "一條指令備份你所有伺服器上的 PostgreSQL 到 Cloudflare R2。多台伺服器統一備份，異地容災，零負擔。",
    "hero.copy": "複製",
    "hero.releases": "版本發佈",
    "why.title": "為什麼選擇 walrus？",
    "why.multi.title": "多伺服器備份",
    "why.multi.desc": "無論你有多少台伺服器、多少個資料庫，統一備份到一個地方集中管理。",
    "why.disaster.title": "異地容災",
    "why.disaster.desc": "備份儲存在遠端雲端，即使原伺服器徹底掛了，也能在任意新機器上還原。",
    "why.pitr.title": "時間點還原",
    "why.pitr.desc": "精確還原到過去 7 天內的任意時刻，而不僅僅是最後一次備份。每 5 分鐘 WAL 歸檔。",
    "why.auto.title": "一次設定，永久自動",
    "why.auto.desc": "設定一次後完全自動執行：每天全量備份 + 每 5 分鐘 WAL 同步。",
    "steps.title": "運作流程",
    "steps.s1.title": "安裝",
    "steps.s2.title": "設定儲存",
    "steps.s3.title": "註冊專案",
    "steps.s4.title": "自動備份",
    "steps.s4.desc": "每天 03:00 + 每 5 分鐘 WAL",
    "steps.s5.title": "監控",
    "steps.s6.title": "隨時還原",
    "features.title": "特色",
    "features.modes": "Docker / 直連兩種模式，統一管理",
    "features.physical": "實體備份，對業務零影響",
    "features.wal": "每 5 分鐘增量同步",
    "features.bwlimit": "頻寬限速，不影響線上流量",
    "features.storage": "Cloudflare R2、Amazon S3、MinIO 等 S3 相容儲存",
    "features.systemd": "系統服務，開機自啟",
    "features.lightweight": "純 Bash，無依賴，超輕量",
    "features.update": "自我更新，無需重新安裝",
    "commands.title": "指令一覽",
    "commands.config": "設定遠端儲存",
    "commands.init": "註冊專案（互動式）",
    "commands.backup": "執行全量備份",
    "commands.sync": "同步 WAL 日誌",
    "commands.restore": "從 R2 還原資料庫",
    "commands.status": "檢視專案狀態",
    "commands.list": "檢視 R2 備份詳情",
    "commands.logs": "檢視日誌（-f 即時追蹤）",
    "commands.update": "更新至最新版本",
    "arch.title": "架構",
    "footer.releases": "版本發佈",
    "footer.issues": "問題回報"
  },
  ja: {
    "hero.title": "walrus",
    "hero.tagline": "インディーハッカーのための PostgreSQL バックアップツール",
    "hero.desc": "ワンコマンドで全ての PostgreSQL を Cloudflare R2 にバックアップ。マルチサーバー、災害復旧、手間ゼロ。",
    "hero.copy": "コピー",
    "hero.releases": "リリース",
    "why.title": "なぜ walrus？",
    "why.multi.title": "マルチサーバーバックアップ",
    "why.multi.desc": "サーバーやデータベースの数に関係なく、1箇所で一元管理。",
    "why.disaster.title": "災害復旧",
    "why.disaster.desc": "バックアップはリモートクラウドに保存。元のサーバーが失われても任意のマシンで復旧可能。",
    "why.pitr.title": "ポイントインタイムリカバリ",
    "why.pitr.desc": "直近7日間の任意の時点に精密復元。5分ごとの WAL アーカイブ。",
    "why.auto.title": "設定したら放置でOK",
    "why.auto.desc": "一度設定すれば完全自動。毎日フルバックアップ + 5分ごとの WAL 同期。",
    "steps.title": "仕組み",
    "steps.s1.title": "インストール",
    "steps.s2.title": "ストレージ設定",
    "steps.s3.title": "プロジェクト登録",
    "steps.s4.title": "自動バックアップ",
    "steps.s4.desc": "毎日 03:00 + 5分ごと WAL",
    "steps.s5.title": "監視",
    "steps.s6.title": "どこでもリストア",
    "features.title": "特徴",
    "features.modes": "Docker / 直接接続の2モード、統一管理",
    "features.physical": "物理バックアップ、アプリへの影響ゼロ",
    "features.wal": "5分ごとの増分同期",
    "features.bwlimit": "帯域制限、本番に影響なし",
    "features.storage": "Cloudflare R2、Amazon S3、MinIO 等 S3互換",
    "features.systemd": "システムサービス、起動時自動開始",
    "features.lightweight": "純Bash、依存関係なし、超軽量",
    "features.update": "セルフアップデート、再インストール不要",
    "commands.title": "コマンド一覧",
    "commands.config": "リモートストレージの設定",
    "commands.init": "プロジェクト登録（対話式）",
    "commands.backup": "フルバックアップの実行",
    "commands.sync": "WAL ログの同期",
    "commands.restore": "R2 からデータベースをリストア",
    "commands.status": "プロジェクトステータスの表示",
    "commands.list": "R2 バックアップの詳細表示",
    "commands.logs": "ログ表示（-f でリアルタイム）",
    "commands.update": "最新版に更新",
    "arch.title": "アーキテクチャ",
    "footer.releases": "リリース",
    "footer.issues": "Issues"
  },
  fr: {
    "hero.title": "walrus",
    "hero.tagline": "L'outil de sauvegarde PostgreSQL pour les indie hackers",
    "hero.desc": "Une seule commande pour sauvegarder toutes vos bases PostgreSQL sur Cloudflare R2. Multi-serveurs, reprise apres sinistre, zero souci.",
    "hero.copy": "Copier",
    "hero.releases": "Versions",
    "why.title": "Pourquoi walrus ?",
    "why.multi.title": "Sauvegarde multi-serveurs",
    "why.multi.desc": "Gerez les sauvegardes de tous vos serveurs en un seul endroit, quel que soit le nombre de bases.",
    "why.disaster.title": "Reprise apres sinistre",
    "why.disaster.desc": "Sauvegardes sur le cloud distant. Restauration sur n'importe quelle machine meme si le serveur est perdu.",
    "why.pitr.title": "Restauration point-in-time",
    "why.pitr.desc": "Restaurez a n'importe quel moment des 7 derniers jours. Archivage WAL toutes les 5 minutes.",
    "why.auto.title": "Configurez et oubliez",
    "why.auto.desc": "Configuration unique, puis tout est automatique. Sauvegarde complete quotidienne + WAL toutes les 5 min.",
    "steps.title": "Fonctionnement",
    "steps.s1.title": "Installer",
    "steps.s2.title": "Configurer stockage",
    "steps.s3.title": "Enregistrer projet",
    "steps.s4.title": "Sauvegarde auto",
    "steps.s4.desc": "Quotidien 03:00 + WAL / 5 min",
    "steps.s5.title": "Surveiller",
    "steps.s6.title": "Restaurer partout",
    "features.title": "Fonctionnalites",
    "features.modes": "Deux modes de deploiement, gestion unifiee",
    "features.physical": "Sauvegarde physique, zero impact sur votre app",
    "features.wal": "Synchronisation incrementale toutes les 5 minutes",
    "features.bwlimit": "Limitation de bande passante, n'affecte pas la production",
    "features.storage": "Cloudflare R2, Amazon S3, MinIO, tout S3-compatible",
    "features.systemd": "Service systeme, demarrage au boot",
    "features.lightweight": "Pur Bash, sans dependances, ultra leger",
    "features.update": "Mise a jour automatique, pas de reinstallation",
    "commands.title": "Commandes",
    "commands.config": "Configurer le stockage distant",
    "commands.init": "Enregistrer un projet (interactif)",
    "commands.backup": "Executer une sauvegarde complete",
    "commands.sync": "Synchroniser les journaux WAL",
    "commands.restore": "Restaurer la base depuis R2",
    "commands.status": "Afficher l'etat du projet",
    "commands.list": "Afficher les sauvegardes R2",
    "commands.logs": "Voir les logs (-f temps reel)",
    "commands.update": "Mettre a jour",
    "arch.title": "Architecture",
    "footer.releases": "Versions",
    "footer.issues": "Signaler un probleme"
  }
};

// ── Apply language ──
function setLang(lang) {
  const dict = i18n[lang] || i18n.en;

  document.querySelectorAll("[data-i18n]").forEach(el => {
    const key = el.getAttribute("data-i18n");
    if (dict[key]) el.textContent = dict[key];
  });

  document.querySelectorAll("[data-i18n-title]").forEach(el => {
    const key = el.getAttribute("data-i18n-title");
    if (dict[key]) el.title = dict[key];
  });

  document.documentElement.lang = lang === "zh" ? "zh-CN" : lang === "tw" ? "zh-TW" : lang;

  document.querySelectorAll(".lang-btn").forEach(btn => {
    btn.classList.toggle("active", btn.dataset.lang === lang);
  });

  localStorage.setItem("walrus-lang", lang);
}

// ── Copy install command ──
function copyInstall() {
  const cmd = document.getElementById("install-cmd").textContent;
  navigator.clipboard.writeText(cmd).then(() => {
    const btn = document.querySelector(".copy-btn");
    const originalHTML = btn.innerHTML;
    btn.innerHTML = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="20 6 9 17 4 12"/></svg>';
    setTimeout(() => { btn.innerHTML = originalHTML; }, 1500);
  });
}

// ── Init ──
document.querySelectorAll(".lang-btn").forEach(btn => {
  btn.addEventListener("click", () => setLang(btn.dataset.lang));
});

const savedLang = localStorage.getItem("walrus-lang") || (navigator.language.startsWith("zh") ? (navigator.language.includes("TW") || navigator.language.includes("HK") ? "tw" : "zh") : navigator.language.startsWith("ja") ? "ja" : navigator.language.startsWith("fr") ? "fr" : "en");
setLang(savedLang);
