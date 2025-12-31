$list = Get-AzSubscription | Out-GridView -PassThru
$filteredSubscriptions = $list

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Remove Logic App Diagnostic Settings" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$DiagnosticsSettingName = "OLD-DIAGNOSTIC-SETTINGS-NAME"
$totalRemoved = 0
$totalSkipped = 0

Write-Host "Retrieving subscriptions..." -ForegroundColor Yellow
Write-Host "Found $($filteredSubscriptions.Count) matching subscription(s)`n" -ForegroundColor Green

foreach ($subscription in $filteredSubscriptions) {
    Write-Host "Processing: $($subscription.Name)..." -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $subscription.Id | Out-Null
    
    $logicApps = Get-AzLogicApp -ErrorAction SilentlyContinue
    Write-Host "  Found $($logicApps.Count) Logic App(s)" -ForegroundColor Gray
    
    foreach ($logicApp in $logicApps) {
        try {
            $settings = Get-AzDiagnosticSetting -ResourceId $logicApp.Id -ErrorAction SilentlyContinue
            
            $targetSetting = $settings | Where-Object { $_.Name -eq $DiagnosticsSettingName }
            
            if ($targetSetting) {
                Write-Host "    Removing '$DiagnosticsSettingName' from $($logicApp.Name)..." -ForegroundColor Yellow
                Remove-AzDiagnosticSetting -ResourceId $logicApp.Id -Name $DiagnosticsSettingName -ErrorAction Stop
                Write-Host "    ✓ Removed successfully" -ForegroundColor Green
                $totalRemoved++
            }
            else {
                Write-Host "    - $($logicApp.Name): Setting not found, skipping" -ForegroundColor Gray
                $totalSkipped++
            }
        }
        catch {
            Write-Host "    ✗ Failed to remove from $($logicApp.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan
Write-Host "Total Removed: $totalRemoved" -ForegroundColor Green
Write-Host "Total Skipped: $totalSkipped" -ForegroundColor Gray
