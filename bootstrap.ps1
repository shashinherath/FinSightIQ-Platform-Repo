# ==============================================================================
# FinSightIQ — Workspace Bootstrap Script (PowerShell for Windows)
# ==============================================================================
# Clones and aligns sibling repositories defined in workspace.lock.
# Leaves repositories at locked refs for reproducibility.
# Safe: Never overwrites uncommitted local changes.
# ==============================================================================
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$env:GIT_TERMINAL_PROMPT = "0"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$WorkspaceDir = Split-Path -Parent $ScriptDir
$LockFile = Join-Path $ScriptDir "workspace.lock"
$EnvFile = Join-Path $ScriptDir ".env"
$EnvExampleFile = Join-Path $ScriptDir ".env.example"

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "FinSightIQ Workspace Bootstrapper (PowerShell)" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "Platform Directory : $ScriptDir"
Write-Host "Workspace Directory: $WorkspaceDir"

# 1. Load .env
if (-not (Test-Path $EnvFile)) {
    if (Test-Path $EnvExampleFile) {
        Write-Host "[WARN] .env not found. Creating from .env.example..." -ForegroundColor Yellow
        Copy-Item $EnvExampleFile $EnvFile
    } else {
        Write-Error "[ERROR] .env and .env.example missing in $ScriptDir."
        exit 1
    }
}

# Parse .env key-value pairs
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not ($line.StartsWith("#"))) {
        $parts = $line.Split('=', 2)
        if ($parts.Count -eq 2) {
            $key = $parts[0].Trim()
            $val = $parts[1].Trim().Trim('"').Trim("'")
            [Environment]::SetEnvironmentVariable($key, $val, "Process")
        }
    }
}

$Owner = [Environment]::GetEnvironmentVariable("FINSIGHTIQ_OWNER", "Process")
if (-not $Owner -or $Owner -eq "YOUR_GITHUB_ORG_OR_USER") {
    Write-Error "[ERROR] FINSIGHTIQ_OWNER is not set in .env."
    exit 1
}

Write-Host "GitHub Owner       : $Owner" -ForegroundColor Green
Write-Host "==============================================================================" -ForegroundColor Cyan

if (-not (Test-Path $LockFile)) {
    Write-Error "[ERROR] workspace.lock not found at $LockFile"
    exit 1
}

$cloned = 0
$existing = 0
$skipped = 0
$failed = 0

Get-Content $LockFile | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#")) {
        return
    }

    $tokens = -split $line
    $repo = $tokens[0]
    $ref = if ($tokens.Count -ge 2) { $tokens[1] } else { "main" }

    $targetDir = Join-Path $WorkspaceDir $repo
    if (-not (Test-Path $targetDir)) {
        if ($repo -eq "finsightiq-web" -and (Test-Path (Join-Path $WorkspaceDir "FinSightIQ-Frontend-Repo"))) {
            $targetDir = Join-Path $WorkspaceDir "FinSightIQ-Frontend-Repo"
        } elseif ($repo -eq "finsightiq-docs" -and (Test-Path (Join-Path $WorkspaceDir "Docs"))) {
            $targetDir = Join-Path $WorkspaceDir "Docs"
        }
    }

    Write-Host "`n--> Processing repository: $repo (Target ref: $ref)" -ForegroundColor Cyan

    if (-not (Test-Path $targetDir)) {
        $repoUrl = "https://github.com/$Owner/$repo.git"
        Write-Host "    Cloning from $repoUrl into $targetDir..."
        try {
            git clone $repoUrl $targetDir 2>$null
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    [OK] Cloned successfully." -ForegroundColor Green
                $cloned++
            } else {
                Write-Host "    [WARN] Repository '$repo' could not be cloned (may not exist yet on GitHub)." -ForegroundColor Yellow
                Write-Host "           Skipping '$repo' without failure." -ForegroundColor Yellow
                $skipped++
                return
            }
        } catch {
            Write-Host "    [WARN] Repository clone failed: $_" -ForegroundColor Yellow
            $skipped++
            return
        }
    } else {
        Write-Host "    Directory exists: $targetDir"
        $existing++
    }

    # Verify if valid git repository
    $isGit = & git -C $targetDir rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    [NOTE] '$targetDir' is not a git repository. Skipping ref checkout." -ForegroundColor DarkGray
        return
    }

    # Check for uncommitted changes
    $status = & git -C $targetDir status --porcelain
    if ($status) {
        Write-Host "    [PRESERVED] Repository has uncommitted changes. Skipping checkout to prevent data loss." -ForegroundColor Yellow
        return
    }

    Write-Host "    Fetching remote tags and branches..."
    & git -C $targetDir fetch --tags --quiet origin 2>$null

    & git -C $targetDir checkout --quiet $ref 2>$null
    if ($LASTEXITCODE -eq 0) {
        $headSha = & git -C $targetDir rev-parse --short HEAD
        Write-Host "    [OK] Checked out '$ref' (HEAD at $headSha)." -ForegroundColor Green
        Write-Host "         NOTE: To develop, run: git checkout -b feat/<name>" -ForegroundColor DarkGray
    } else {
        Write-Host "    [ERROR] Failed to check out ref '$ref' in $repo." -ForegroundColor Red
        $failed++
    }
}

Write-Host "`n==============================================================================" -ForegroundColor Cyan
Write-Host "Bootstrap Summary:" -ForegroundColor Cyan
Write-Host "  Cloned  : $cloned"
Write-Host "  Existing: $existing"
Write-Host "  Skipped : $skipped (uncreated remote repos)"
Write-Host "  Failed  : $failed"
Write-Host "==============================================================================" -ForegroundColor Cyan

if ($failed -gt 0) {
    Write-Error "[FAILURE] One or more repositories failed ref checkout."
    exit 1
}

Write-Host "[SUCCESS] Workspace synchronization complete." -ForegroundColor Green
exit 0
