param(
    [string]$Target = "local",
    [string]$Plugin = "all",
    [string]$Action = "install",
    [switch]$WithSeed = $true
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$cloudDir = Split-Path -Parent (Split-Path -Parent $scriptDir)
Set-Location $cloudDir

Write-Host "====================================================================" -ForegroundColor Cyan
Write-Host " [TUQUET-SUPABASE] Core Plugins Runner (Action: $Action, Target: $Target)" -ForegroundColor Cyan
Write-Host " Working Directory: $cloudDir" -ForegroundColor DarkGray
Write-Host "====================================================================" -ForegroundColor Cyan

$dbContainer = docker ps --filter "name=supabase_db" --format "{{.Names}}" | Select-Object -First 1

if ($Action -eq "uninstall") {
    $canonicalPlugins = @(
        @{ Id = "webhooks"; File = "supabase/plugins/webhooks/uninstall.sql"; Desc = "Asynchronous Outbox & Webhooks (schema: events)" },
        @{ Id = "subscriptions"; File = "supabase/plugins/subscriptions/uninstall.sql"; Desc = "Subscriptions & Quota (schema: billing)" },
        @{ Id = "secrets"; File = "supabase/plugins/secrets/uninstall.sql"; Desc = "Zero-Knowledge DEK & Vault (schema: secrets)" }
    )
} else {
    $canonicalPlugins = @(
        @{ Id = "secrets"; File = "supabase/plugins/secrets/install.sql"; Desc = "Zero-Knowledge DEK & Vault (schema: secrets)" },
        @{ Id = "subscriptions"; File = "supabase/plugins/subscriptions/install.sql"; Desc = "Subscriptions & Quota (schema: billing)" },
        @{ Id = "webhooks"; File = "supabase/plugins/webhooks/install.sql"; Desc = "Asynchronous Outbox & Webhooks (schema: events)" }
    )
}

foreach ($item in $canonicalPlugins) {
    if ($Plugin -ne "all" -and $Plugin -ne $item.Id) {
        continue
    }

    if (-not (Test-Path $item.File)) {
        Write-Warning "[-] Plugin $Action file not found, skipping: $($item.File)"
        continue
    }

    Write-Host "`n--> [$Action] $($item.Desc)..." -ForegroundColor Yellow

    if ($Target -eq "local" -and $dbContainer) {
        Get-Content $item.File -Raw | docker exec -i $dbContainer psql -U postgres -d postgres -v ON_ERROR_STOP=1
    } else {
        supabase db query "--$Target" -f $item.File
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Error "[-] Failed to $Action plugin: $($item.Id)"
        exit 1
    }
    Write-Host "    [OK] Plugin $($item.Id) applied successfully." -ForegroundColor Green

    if ($Action -eq "install" -and $WithSeed) {
        $seedFile = "supabase/plugins/$($item.Id)/seed.sql"
        if (Test-Path $seedFile) {
            Write-Host "    --> Applying sample data: $seedFile" -ForegroundColor DarkCyan
            if ($Target -eq "local" -and $dbContainer) {
                Get-Content $seedFile -Raw | docker exec -i $dbContainer psql -U postgres -d postgres -v ON_ERROR_STOP=1
            } else {
                supabase db query "--$Target" -f $seedFile
            }
            Write-Host "    [OK] Sample data applied for $($item.Id)" -ForegroundColor Green
        }
    }
}

Write-Host "`n[SUCCESS] Plugins pipeline completed successfully!" -ForegroundColor Green
