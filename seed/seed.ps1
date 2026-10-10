# ==============================================================================
# FinSightIQ — Demo & Test Data Seeding Orchestrator (PowerShell for Windows)
# ==============================================================================
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PlatformDir = Split-Path -Parent $ScriptDir
$EnvFile = Join-Path $PlatformDir ".env"
$ComposeFile = Join-Path $PlatformDir "docker-compose.yml"

if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not ($line.StartsWith("#"))) {
            $parts = $line.Split('=', 2)
            if ($parts.Count -eq 2) {
                [Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim().Trim('"').Trim("'"), "Process")
            }
        }
    }
}

$PostgresUser = if ($env:POSTGRES_USER) { $env:POSTGRES_USER } else { "postgres" }

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "FinSightIQ Demo Data Seeding Orchestration (PowerShell)" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan

# Ensure postgres is running
$runningServices = & docker compose -f $ComposeFile ps --status running --services
if ($runningServices -notcontains "postgres") {
    Write-Host "[INFO] PostgreSQL is not running. Starting postgres..." -ForegroundColor Yellow
    & docker compose -f $ComposeFile up -d postgres
    Write-Host "Waiting for PostgreSQL ready..." -ForegroundColor Yellow
    do {
        Start-Sleep -Seconds 1
        & docker compose -f $ComposeFile exec -T postgres pg_isready -U $PostgresUser 2>$null
    } while ($LASTEXITCODE -ne 0)
}

$seeded = 0
$skipped = 0

# 1. usersdb
Write-Host "`n--> Checking 'usersdb' (User Service)..." -ForegroundColor Cyan
$usersExists = & docker compose -f $ComposeFile exec -T postgres `
    psql -U $PostgresUser -d usersdb -tAc "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'users');" 2>$null

if ($usersExists -eq "t") {
    Write-Host "    Applying demo user accounts..." -ForegroundColor Yellow
    $usersSql = Join-Path $ScriptDir "sql\users_seed.sql"
    Get-Content $usersSql | & docker compose -f $ComposeFile exec -T postgres psql -U $PostgresUser -d usersdb
    Write-Host "    [SEEDED] Successfully seeded default demo users." -ForegroundColor Green
    $seeded++
} else {
    Write-Host "    [SKIPPED] Table 'users' does not exist in 'usersdb'." -ForegroundColor DarkGray
    Write-Host "              User Service migrations have not been executed yet." -ForegroundColor DarkGray
    $skipped++
}

# 2. marketdb
Write-Host "`n--> Checking 'marketdb' (Market Data Service)..." -ForegroundColor Cyan
$symbolsExists = & docker compose -f $ComposeFile exec -T postgres `
    psql -U $PostgresUser -d marketdb -tAc "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'symbols');" 2>$null

if ($symbolsExists -eq "t") {
    Write-Host "    Applying 30 standard market symbols..." -ForegroundColor Yellow
    $symbolsSql = Join-Path $ScriptDir "sql\market_symbols_seed.sql"
    Get-Content $symbolsSql | & docker compose -f $ComposeFile exec -T postgres psql -U $PostgresUser -d marketdb
    Write-Host "    [SEEDED] Successfully seeded 30 stock market symbols." -ForegroundColor Green
    $seeded++
} else {
    Write-Host "    [SKIPPED] Table 'symbols' does not exist in 'marketdb'." -ForegroundColor DarkGray
    Write-Host "              Market Data Service migrations have not been executed yet." -ForegroundColor DarkGray
    $skipped++
}

Write-Host "`n==============================================================================" -ForegroundColor Cyan
Write-Host "Seeding Summary:" -ForegroundColor Cyan
Write-Host "  Datasets Seeded : $seeded"
Write-Host "  Datasets Skipped: $skipped"
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "[SUCCESS] Demo seeding orchestration completed." -ForegroundColor Green
exit 0
