# Contributing to walrus

## Development

```bash
# Clone the repo
git clone https://github.com/LayFz/walrus.git
cd walrus

# Run locally (no install needed)
./walrus help
```

walrus is a pure Bash project. For local development, just run `./walrus` directly — the script auto-detects the `lib/` directory and runs in source mode.

## Release Process

To publish a new version, simply create a git tag:

```bash
# 1. Optionally update version in lib/constants.sh (CI will override)
# 2. Tag and push
git tag v2.1.0
git push origin v2.1.0
```

GitHub Actions will automatically:

1. Extract version from the tag, inject into `lib/constants.sh`
2. Package all files into `walrus-x.y.z.tar.gz`
3. Generate SHA256 checksum
4. Publish to [GitHub Releases](https://github.com/LayFz/walrus/releases) with auto-generated release notes

Users running `install.sh` will automatically pull the latest release tarball.

## Versioning

Follows [Semantic Versioning](https://semver.org/):

- `vX.0.0` — Breaking changes to config or commands
- `vX.Y.0` — New commands or features
- `vX.Y.Z` — Bug fixes

## Project Structure

```
walrus/
├── walrus                    # Entry point: module loader + command dispatch
├── install.sh                # Remote installer (pulls from GitHub Releases)
├── lib/                      # Shared libraries
│   ├── constants.sh          # Constants & version
│   ├── colors.sh             # Terminal colors
│   ├── logger.sh             # Logging
│   ├── cleanup.sh            # Signal handling & temp file cleanup
│   ├── utils.sh              # Interactive prompts & utilities
│   ├── lock.sh               # Concurrency lock
│   ├── project.sh            # Project config management
│   ├── r2.sh                 # rclone/R2 wrapper
│   └── pg.sh                 # PostgreSQL abstraction (docker/direct)
├── commands/                 # Subcommands
├── .github/workflows/
│   └── release.yml           # Release pipeline
├── CONTRIBUTING.md           # This file
└── README.md
```

## Install Script Internals

How `install.sh` works:

1. Queries GitHub API for the latest release version (or uses `WALRUS_VERSION` env var)
2. Downloads the corresponding tarball from GitHub Releases
3. Verifies SHA256 checksum
4. Extracts to `/opt/walrus/`, preserving existing `conf/`, `data/`, `logs/` directories
5. Installs `postgresql-client` if not already present
6. Copies the main binary to `/usr/local/bin/walrus`
