# Windows (PowerShell) setup

ToolJet has three runtime tiers (plugins, server, frontend) plus an optional
Docker-based local stack. This guide covers both paths on Windows 10/11.

## Prerequisites

| Tool           | Version    | Notes                                  |
| -------------- | ---------- | -------------------------------------- |
| Node.js        | `18.18.2`  | Exact pin (see `.nvmrc`)               |
| npm            | `9.8.1`    | Bundled with Node; pinned by `engines` |
| Git            | latest     |                                        |
| Docker Desktop | latest     | Optional — simplest path for Postgres  |
| PostgreSQL     | 13+        | Only if you skip Docker                |

## Automated setup

```powershell
pwsh -File .\scripts\windows-setup.ps1
pwsh -File .\scripts\windows-setup.ps1 -InstallDocker
```

What it does:

1. Verifies / installs Node 18.18.2 and npm 9.8.1.
2. Verifies / installs Git (and optionally Docker Desktop).
3. Runs `npm install` at the root and in each sub-package: `plugins`,
   `frontend`, `server`.

### Flags

- `-SkipInstall` — verify tools but skip dependency installation.
- `-InstallDocker` — also install Docker Desktop via winget.

## Manual setup

```powershell
# 1. Install prerequisites
winget install OpenJS.NodeJS.LTS --version 18.18.2
winget install Git.Git
# Optional:
winget install Docker.DockerDesktop

npm install -g npm@9.8.1

# 2. Clone the repo
git clone https://github.com/nickhandymanservice-ctrl/ai3.git
Set-Location ai3

# 3. Install dependencies
npm install
npm --prefix plugins install
npm --prefix frontend install
npm --prefix server install
```

## Running the app

### Docker (easy mode)

```powershell
docker compose up -d                # postgres, redis, server, frontend
Start-Process 'http://localhost:8082'
```

### Native (manual mode)

```powershell
# 1. Copy and edit env file
Copy-Item .env.example .env
notepad .env

# 2. Bootstrap database (Postgres must be running)
npm run db:setup

# 3. Start server + frontend in two terminals
npm --prefix server run start:dev
npm --prefix frontend run start
```

## Troubleshooting

### `node-gyp` errors when installing native modules

Install the C++ build tools and Python:

```powershell
winget install Microsoft.VisualStudio.2022.BuildTools --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
winget install Python.Python.3.12
```

### npm warns about Node version mismatch

The repo pins `node@18.18.2`. Switch with nvm-windows:

```powershell
nvm install 18.18.2
nvm use 18.18.2
```

### Long path errors

```powershell
git config --system core.longpaths true
```

### Execution policy blocks the script

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### PostgreSQL connection refused

- Docker path: `docker compose ps` and confirm Postgres is healthy.
- Native path: edit `.env` to match your local Postgres credentials.
