$list = Get-AzSubscription | Out-GridView -PassThru
$filteredSubscriptions = $list

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Remove SQL Server Diagnostic Settings" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$DiagnosticsSettingName = "OLD-DIAGNOSTIC-SETTINGS-NAME"
$totalRemoved = 0
$totalSkipped = 0

Write-Host "Retrieving subscriptions..." -ForegroundColor Yellow
Write-Host "Found $($filteredSubscriptions.Count) matching subscription(s)`n" -ForegroundColor Green

foreach ($subscription in $filteredSubscriptions) {
    Write-Host "Processing: $($subscription.Name)..." -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $subscription.Id | Out-Null
    
    $sqlServers = Get-AzSqlServer -ErrorAction SilentlyContinue
    Write-Host "  Found $($sqlServers.Count) SQL Server(s)" -ForegroundColor Gray
    
    foreach ($sqlServer in $sqlServers) {
        try {
            Write-Host "    Checking $($sqlServer.ServerName)..." -ForegroundColor Cyan
            $settings = Get-AzDiagnosticSetting -ResourceId $sqlServer.ResourceId -ErrorAction SilentlyContinue
            
            if ($settings) {
                Write-Host "      Found diagnostic settings: $($settings.Name -join ', ')" -ForegroundColor Gray
            }
            
            $targetSetting = $settings | Where-Object { $_.Name -eq $DiagnosticsSettingName }
            
            if ($targetSetting) {
                Write-Host "      Removing '$DiagnosticsSettingName'..." -ForegroundColor Yellow
                Remove-AzDiagnosticSetting -ResourceId $sqlServer.ResourceId -Name $DiagnosticsSettingName -ErrorAction Stop
                Write-Host "      ✓ Removed successfully" -ForegroundColor Green
                $totalRemoved++
            }
            else {
                Write-Host "      - Setting '$DiagnosticsSettingName' not found, skipping" -ForegroundColor Gray
                $totalSkipped++
            }
        }
        catch {
            Write-Host "      ✗ Failed to remove from $($sqlServer.ServerName): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan
Write-Host "Total Removed: $totalRemoved" -ForegroundColor Green
Write-Host "Total Skipped: $totalSkipped" -ForegroundColor Gray
