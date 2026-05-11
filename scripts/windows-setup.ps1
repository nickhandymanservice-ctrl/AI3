#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstraps a Windows dev environment for ToolJet (ai3).

.DESCRIPTION
    Verifies Node.js (18.18.2), npm (9.8.1), Git, and — optionally — Docker
    Desktop are available, installs prerequisites via winget, then runs the
    multi-package install (root, plugins, frontend, server).

.PARAMETER SkipInstall
    Verify tools but skip the dependency install pass.

.PARAMETER InstallDocker
    Also install Docker Desktop via winget (recommended for local dev).

.EXAMPLE
    pwsh -File .\scripts\windows-setup.ps1

.EXAMPLE
    pwsh -File .\scripts\windows-setup.ps1 -InstallDocker
#>

[CmdletBinding()]
param(
    [switch]$SkipInstall,
    [switch]$InstallDocker
)

$ErrorActionPreference = 'Stop'

$RequiredNodeVersion = '18.18.2'
$RequiredNpmVersion  = '9.8.1'

function Test-Command {
    param([Parameter(Mandatory)][string]$Name)
    return [bool](Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Get-CleanVersion {
    param([Parameter(Mandatory)][string]$Command)
    try {
        $raw = & $Command --version 2>$null | Select-Object -First 1
        return ($raw -replace '^v', '').Trim()
    } catch { return $null }
}

function Install-Winget {
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Label = $Id,
        [string]$Version
    )
    if (-not (Test-Command 'winget')) {
        Write-Warning "winget unavailable. Install '$Label' manually."
        return $false
    }
    $wingetArgs = @('install', '--id', $Id, '--silent',
                    '--accept-package-agreements', '--accept-source-agreements')
    if ($Version) { $wingetArgs += @('--version', $Version) }
    Write-Host "Installing $Label via winget..." -ForegroundColor Cyan
    winget @wingetArgs
    return ($LASTEXITCODE -eq 0)
}

Write-Host ''
Write-Host '=== ToolJet (ai3) Windows setup ===' -ForegroundColor Green
Write-Host ''

# ---- Node.js ----
$nodeVersion = Get-CleanVersion 'node'
if (-not $nodeVersion) {
    Write-Host 'Node.js: not found.' -ForegroundColor Yellow
    Install-Winget -Id 'OpenJS.NodeJS.LTS' -Label "Node.js $RequiredNodeVersion" -Version $RequiredNodeVersion | Out-Null
    Write-Host 'Open a new PowerShell window, then re-run this script.' -ForegroundColor Yellow
    return
} elseif ($nodeVersion -ne $RequiredNodeVersion) {
    Write-Warning "Node.js $nodeVersion detected. Repo pins to $RequiredNodeVersion (see .nvmrc)."
    Write-Warning "Switch with nvm-windows: nvm install $RequiredNodeVersion ; nvm use $RequiredNodeVersion"
} else {
    Write-Host "Node.js $nodeVersion: OK" -ForegroundColor Green
}

# ---- npm ----
$npmVersion = Get-CleanVersion 'npm'
if (-not $npmVersion) {
    Write-Warning 'npm not found. It normally ships with Node.js — something is wrong with the Node install.'
} elseif ($npmVersion -ne $RequiredNpmVersion) {
    Write-Host "npm $npmVersion -> $RequiredNpmVersion" -ForegroundColor Yellow
    npm install -g "npm@$RequiredNpmVersion"
} else {
    Write-Host "npm $npmVersion: OK" -ForegroundColor Green
}

# ---- Git ----
if (-not (Test-Command 'git')) {
    Write-Host 'Git: not found.' -ForegroundColor Yellow
    Install-Winget -Id 'Git.Git' -Label 'Git' | Out-Null
} else {
    Write-Host "$(git --version): OK" -ForegroundColor Green
}

# ---- Docker (optional) ----
if ($InstallDocker -and -not (Test-Command 'docker')) {
    Install-Winget -Id 'Docker.DockerDesktop' -Label 'Docker Desktop' | Out-Null
    Write-Host 'Sign out / in (or reboot) so Docker Desktop can complete setup.' -ForegroundColor Yellow
} elseif (Test-Command 'docker') {
    Write-Host "$(docker --version): OK" -ForegroundColor Green
}

if ($SkipInstall) {
    Write-Host ''
    Write-Host 'Skipping install step (-SkipInstall set).' -ForegroundColor Yellow
    return
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Push-Location $repoRoot
try {
    Write-Host ''
    Write-Host 'Installing root devDependencies...' -ForegroundColor Cyan
    npm install

    Write-Host ''
    Write-Host 'Installing plugins package...' -ForegroundColor Cyan
    npm --prefix plugins install

    Write-Host ''
    Write-Host 'Installing frontend package...' -ForegroundColor Cyan
    npm --prefix frontend install

    Write-Host ''
    Write-Host 'Installing server package...' -ForegroundColor Cyan
    npm --prefix server install
} finally {
    Pop-Location
}

Write-Host ''
Write-Host 'Setup complete.' -ForegroundColor Green
Write-Host ''
Write-Host 'Next steps:' -ForegroundColor Cyan
Write-Host '  Copy-Item .env.example .env       # then edit values for your DB'
Write-Host '  npm run db:setup                  # bootstrap Postgres schema'
Write-Host '  npm --prefix server run start:dev # start the API'
Write-Host '  npm --prefix frontend run start   # start the web UI on :8082'
Write-Host ''
Write-Host 'Or use Docker:'
Write-Host '  docker compose up -d'
