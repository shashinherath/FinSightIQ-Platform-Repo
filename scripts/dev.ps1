# ==============================================================================
# FinSightIQ Platform — Developer Workflow Helper (PowerShell for Windows)
# ==============================================================================
# Equivalent to Make targets for Windows developers without GNU Make installed.
# Usage: .\scripts\dev.ps1 <command>
# ==============================================================================
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [ValidateSet("help", "bootstrap", "up", "up-monitoring", "up-all", "down", "ps", "logs", "build", "provision", "migrate", "seed", "test-all", "reset")]
    [string]$Command = "help"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PlatformDir = Split-Path -Parent $ScriptDir
$ComposeFile = Join-Path $PlatformDir "docker-compose.yml"

switch ($Command) {
    "help" {
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host "FinSightIQ Platform Orchestration Commands (PowerShell)" -ForegroundColor Cyan
        Write-Host "==============================================================================" -ForegroundColor Cyan
        Write-Host "  bootstrap      Synchronize and checkout sibling repositories defined in workspace.lock"
        Write-Host "  up             Start core infrastructure (PostgreSQL, Redis, RabbitMQ)"
        Write-Host "  up-monitoring  Start infrastructure plus Prometheus and Grafana"
        Write-Host "  up-all         Start infrastructure, monitoring, and services"
        Write-Host "  down           Stop containers without destroying data (non-destructive)"
        Write-Host "  ps             View container status and health check results"
        Write-Host "  logs           Tail logs from running containers"
        Write-Host "  build          Build container images"
        Write-Host "  provision      Provision PostgreSQL logical databases"
        Write-Host "  migrate        Run Flyway migrations across sibling service repositories"
        Write-Host "  seed           Seed demo development fixtures"
        Write-Host "  test-all       Run platform tests"
        Write-Host "  reset          DESTRUCTIVE: Wipe containers and persistent data volumes"
        Write-Host "==============================================================================" -ForegroundColor Cyan
    }
    "bootstrap" {
        & (Join-Path $PlatformDir "bootstrap.ps1")
    }
    "up" {
        & docker compose -f $ComposeFile up -d postgres redis rabbitmq
    }
    "up-monitoring" {
        & docker compose -f $ComposeFile --profile monitoring up -d
    }
    "up-all" {
        & docker compose -f $ComposeFile --profile monitoring --profile services up -d
    }
    "down" {
        & docker compose -f $ComposeFile down
    }
    "ps" {
        & docker compose -f $ComposeFile ps
    }
    "logs" {
        & docker compose -f $ComposeFile logs -f
    }
    "build" {
        & docker compose -f $ComposeFile build
    }
    "provision" {
        & (Join-Path $PlatformDir "migrate\provision.ps1")
    }
    "migrate" {
        & (Join-Path $PlatformDir "migrate\migrate.ps1")
    }
    "seed" {
        & (Join-Path $PlatformDir "seed\seed.ps1")
    }
    "test-all" {
        $testDir = Join-Path $PlatformDir "tests\e2e"
        Push-Location $testDir
        try {
            npm test
        } finally {
            Pop-Location
        }
    }
    "reset" {
        Write-Host "WARNING: This will permanently delete all container data volumes (Postgres, Redis, RabbitMQ, Grafana)!" -ForegroundColor Red
        $confirm = Read-Host "Type 'yes' to proceed with destructive reset"
        if ($confirm -eq "yes") {
            & docker compose -f $ComposeFile down -v
            Write-Host "Platform reset complete. Clean state restored." -ForegroundColor Green
        } else {
            Write-Host "Reset cancelled." -ForegroundColor Yellow
        }
    }
}
