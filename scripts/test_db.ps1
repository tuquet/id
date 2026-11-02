param(
    [string]$Target = "local",
    [string]$SpecificTest = ""
)

$ErrorActionPreference = "Stop"

# Auto-resolve cloud directory relative to script root
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cloudDir = Split-Path -Parent $scriptDir
Set-Location $cloudDir

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host " [OPERON-CLOUD] Database Test Suite Runner (Target: $Target)" -ForegroundColor Cyan
Write-Host " Working Directory: $cloudDir" -ForegroundColor DarkGray
Write-Host "====================================================================" -ForegroundColor Cyan

# 1. Locate Docker container or fallback to supabase CLI
$dbContainer = docker ps --filter "name=supabase_db" --format "{{.Names}}" | Select-Object -First 1
if (-not $dbContainer) {
    Write-Warning "Could not find a running supabase_db container. Falling back to 'supabase db query'..."
}

# 2. Ensure provision helper exists
$helperFile = "tests/presets/sql/00_provision_helper.sql"
if (Test-Path $helperFile) {
    Write-Host "--> Provisioning test helper ($helperFile)..." -ForegroundColor Yellow
    if ($dbContainer -and $Target -eq "local") {
        Get-Content $helperFile -Raw | docker exec -i $dbContainer psql -U postgres -d postgres -v ON_ERROR_STOP=1 | Out-Null
    } else {
        supabase db query "--$Target" -f $helperFile | Out-Null
    }
}

# 3. Collect test files
if ($SpecificTest) {
    $testFiles = Get-ChildItem -Path "tests/db" -Filter "*$SpecificTest*.sql" | Sort-Object Name
} else {
    $testFiles = Get-ChildItem -Path "tests/db" -Filter "*.sql" | Sort-Object Name
}

if ($testFiles.Count -eq 0) {
    Write-Error "No matching SQL test files found in tests/db!"
    exit 1
}

$passCount = 0
$failCount = 0

foreach ($file in $testFiles) {
    Write-Host "`n--> Running Test: $($file.Name)" -ForegroundColor Magenta
    try {
        if ($dbContainer -and $Target -eq "local") {
            $output = Get-Content $file.FullName -Raw | docker exec -i $dbContainer psql -U postgres -d postgres -v ON_ERROR_STOP=1
        } else {
            $output = supabase db query "--$Target" -f $file.FullName
        }
        
        $output | ForEach-Object { Write-Host $_ }
        
        if ($LASTEXITCODE -ne 0) {
            throw "psql exited with code $LASTEXITCODE"
        }
        Write-Host "    [PASS] $($file.Name)" -ForegroundColor Green
        $passCount++
    } catch {
        Write-Host "    [FAIL] $($file.Name): $_" -ForegroundColor Red
        $failCount++
        exit 1
    }
}

Write-Host "`n====================================================================" -ForegroundColor Cyan
Write-Host " [SUMMARY] Passed: $passCount | Failed: $failCount (Total: $($testFiles.Count))" -ForegroundColor Green
Write-Host " Database integrity verified 100% successfully." -ForegroundColor Green
Write-Host "====================================================================" -ForegroundColor Cyan
