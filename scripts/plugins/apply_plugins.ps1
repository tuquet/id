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
Write-Host " [ID-PLATFORM] Product Modules Runner (Action: $Action, Target: $Target)" -ForegroundColor Cyan
Write-Host " Working Directory: $cloudDir" -ForegroundColor DarkGray
Write-Host "====================================================================" -ForegroundColor Cyan

$dbContainer = docker ps --filter "name=supabase_db" --format "{{.Names}}" | Select-Object -First 1

if ($Action -eq "uninstall") {
    $canonicalPlugins = @(
        @{ Id = "operon"; File = "supabase/plugins/operon/uninstall.sql"; Desc = "Operon Runtime Engine (schema: operon)" },
        @{ Id = "store"; File = "supabase/plugins/store/uninstall.sql"; Desc = "Store Engine (schema: medusa)" },
        @{ Id = "dispatch"; File = "supabase/plugins/dispatch/uninstall.sql"; Desc = "Dispatch & Realtime Outbox (schema: events)" },
        @{ Id = "licensing"; File = "supabase/plugins/licensing/uninstall.sql"; Desc = "Licensing & Quotas (schema: billing)" },
        @{ Id = "vault"; File = "supabase/plugins/vault/uninstall.sql"; Desc = "Vault (Zero-Knowledge DEK & Vault)" }
    )
} else {
    $canonicalPlugins = @(
        @{ Id = "vault"; File = "supabase/plugins/vault/install.sql"; Desc = "Vault (Zero-Knowledge DEK & Vault)" },
        @{ Id = "licensing"; File = "supabase/plugins/licensing/install.sql"; Desc = "Licensing & Quotas (schema: billing)" },
        @{ Id = "dispatch"; File = "supabase/plugins/dispatch/install.sql"; Desc = "Dispatch & Realtime Outbox (schema: events)" },
        @{ Id = "store"; File = "supabase/plugins/store/install.sql"; Desc = "Store Engine (schema: medusa)" },
        @{ Id = "operon"; File = "supabase/plugins/operon/install.sql"; Desc = "Operon Runtime Engine (schema: operon)" }
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
    Write-Host "    [OK] Module $($item.Id) applied successfully." -ForegroundColor Green

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

Write-Host "`n[SUCCESS] Product modules pipeline completed successfully!" -ForegroundColor Green
