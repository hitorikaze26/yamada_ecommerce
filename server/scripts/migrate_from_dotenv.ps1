# Option A: load SECRET_KEY / JWT_SECRET_KEY from server/.env, then migrate.
# DATABASE_URL: use current shell value if set, otherwise read from .env
#
# Usage:
#   cd server
#   .venv\Scripts\Activate.ps1
#   $env:DATABASE_URL = "postgresql+psycopg2://...@....pooler.supabase.com:6543/postgres?sslmode=require"
#   .\scripts\migrate_from_dotenv.ps1

$ErrorActionPreference = "Stop"
$serverDir = Split-Path $PSScriptRoot -Parent
Set-Location $serverDir

$preservedDatabaseUrl = $env:DATABASE_URL

$envFile = Join-Path $serverDir ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith("#")) { return }
        $idx = $line.IndexOf("=")
        if ($idx -lt 1) { return }
        $name = $line.Substring(0, $idx).Trim()
        $value = $line.Substring($idx + 1).Trim().Trim('"').Trim("'")
        if ($name) { Set-Item -Path "env:$name" -Value $value }
    }
}

if ($preservedDatabaseUrl) {
    $env:DATABASE_URL = $preservedDatabaseUrl
}

if (-not $env:DATABASE_URL) {
    Write-Error @"
DATABASE_URL is not set.
  - Add DATABASE_URL to server/.env (Supabase pooler :6543), OR
  - Set it in this shell before running:
      `$env:DATABASE_URL = 'postgresql+psycopg2://...'
"@
}

if (-not $env:SECRET_KEY -or -not $env:JWT_SECRET_KEY) {
    Write-Error "SECRET_KEY and JWT_SECRET_KEY must be in server/.env"
}

$env:FLASK_ENV = "production"
$env:FLASK_APP = "app:create_app"

$hostPart = ($env:DATABASE_URL -split "@")[-1].Split("/")[0]
Write-Host "Target database: $hostPart"
Write-Host "Running flask db upgrade..."
& .\.venv\Scripts\flask.exe db upgrade
Write-Host "Current revision:"
& .\.venv\Scripts\flask.exe db current
