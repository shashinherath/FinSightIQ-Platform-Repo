# ==============================================================================
# FinSightIQ — Database Provisioning Script (PowerShell for Windows)
# ==============================================================================
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PlatformDir = Split-Path -Parent $ScriptDir
$ComposeFile = Join-Path $PlatformDir "docker-compose.yml"

Write-Host "Checking PostgreSQL container status..." -ForegroundColor Cyan
$runningServices = & docker compose -f $ComposeFile ps --status running --services
if ($runningServices -notcontains "postgres") {
    Write-Host "[INFO] PostgreSQL container is not running. Starting postgres..." -ForegroundColor Yellow
    & docker compose -f $ComposeFile up -d postgres
    Write-Host "Waiting for PostgreSQL to become ready..." -ForegroundColor Yellow
    do {
        Start-Sleep -Seconds 1
        & docker compose -f $ComposeFile exec -T postgres pg_isready -U postgres 2>$null
    } while ($LASTEXITCODE -ne 0)
}

Write-Host "Executing database provisioning inside postgres container..." -ForegroundColor Cyan
& docker compose -f $ComposeFile exec -T postgres bash /docker-entrypoint-initdb.d/init-databases.sh

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] All FinSightIQ logical databases provisioned." -ForegroundColor Green
} else {
    Write-Error "[FAILURE] Database provisioning failed."
}
