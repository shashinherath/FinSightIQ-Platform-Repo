# ==============================================================================
# FinSightIQ — Flyway Database Migration Orchestration (PowerShell for Windows)
# ==============================================================================
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PlatformDir = Split-Path -Parent $ScriptDir
$WorkspaceDir = Split-Path -Parent $PlatformDir
$EnvFile = Join-Path $PlatformDir ".env"
$ComposeFile = Join-Path $PlatformDir "docker-compose.yml"

# Load .env if present
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
$PostgresPassword = if ($env:POSTGRES_PASSWORD) { $env:POSTGRES_PASSWORD } else { "postgres_dev_password" }
$FlywayImage = "flyway/flyway:10-alpine"
$DockerNetwork = "finsightiq-network"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "FinSightIQ Flyway Migration Orchestration (PowerShell)" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "Workspace Directory : $WorkspaceDir"
Write-Host "Docker Network      : $DockerNetwork"
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

$serviceMap = @(
    @{ Repo = "finsightiq-user-service"; Db = "usersdb" },
    @{ Repo = "finsightiq-market-data-service"; Db = "marketdb" },
    @{ Repo = "finsightiq-prediction-service"; Db = "predictiondb" },
    @{ Repo = "finsightiq-sentiment-service"; Db = "sentimentdb" },
    @{ Repo = "finsightiq-portfolio-service"; Db = "portfoliodb" }
)

$applied = 0
$skipped = 0
$failed = 0

foreach ($item in $serviceMap) {
    $repo = $item.Repo
    $db = $item.Db
    $migrationsDir = Join-Path $WorkspaceDir (Join-Path $repo "db\migrations")

    Write-Host "`n--> Service: $repo (Target Database: $db)" -ForegroundColor Cyan

    if (-not (Test-Path $migrationsDir)) {
        Write-Host "    [SKIPPED] Migration directory not found: $migrationsDir" -ForegroundColor DarkGray
        Write-Host "              Repository '$repo' may not yet be initialized in current sprint." -ForegroundColor DarkGray
        $skipped++
        continue
    }

    $sqlFiles = Get-ChildItem -Path $migrationsDir -Filter "*.sql" -File
    if ($sqlFiles.Count -eq 0) {
        Write-Host "    [SKIPPED] No .sql migration files found in $migrationsDir." -ForegroundColor DarkGray
        $skipped++
        continue
    }

    Write-Host "    Found $($sqlFiles.Count) migration file(s). Executing Flyway migrate..." -ForegroundColor Yellow

    # Format Windows path for Docker volume mount
    $mountPath = ($migrationsDir -replace '\\', '/').Replace(':', '')
    if (-not $mountPath.StartsWith('/')) {
        $mountPath = "/$mountPath"
    }
    # Alternatively use local absolute path with quotes
    & docker run --rm `
        --network $DockerNetwork `
        -v "${migrationsDir}:/flyway/sql:ro" `
        $FlywayImage `
        "-url=jdbc:postgresql://postgres:5432/$db" `
        "-user=$PostgresUser" `
        "-password=$PostgresPassword" `
        "-connectRetries=10" `
        migrate

    if ($LASTEXITCODE -eq 0) {
        Write-Host "    [OK] Successfully migrated database '$db'." -ForegroundColor Green
        $applied++
    } else {
        Write-Host "    [ERROR] Flyway migration failed for service '$repo' on database '$db' (Exit code: $LASTEXITCODE)." -ForegroundColor Red
        $failed++
        break
    }
}

Write-Host "`n==============================================================================" -ForegroundColor Cyan
Write-Host "Migration Summary:" -ForegroundColor Cyan
Write-Host "  Applied: $applied"
Write-Host "  Skipped: $skipped"
Write-Host "  Failed : $failed"
Write-Host "==============================================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    Write-Error "[FAILURE] Database migration orchestration encountered an error."
    exit 1
}

Write-Host "[SUCCESS] Migration orchestration finished cleanly." -ForegroundColor Green
exit 0
