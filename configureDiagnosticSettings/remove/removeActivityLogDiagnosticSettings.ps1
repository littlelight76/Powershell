$list = Get-AzSubscription | Out-GridView -PassThru
$filteredSubscriptions = $list

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Remove Activity Log Diagnostic Settings" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$DiagnosticsSettingName = "OLD-DIAGNOSTIC-SETTINGS-NAME"
$totalRemoved = 0
$totalSkipped = 0

Write-Host "Retrieving subscriptions..." -ForegroundColor Yellow
Write-Host "Found $($filteredSubscriptions.Count) matching subscription(s)`n" -ForegroundColor Green

foreach ($subscription in $filteredSubscriptions) {
    Write-Host "Processing: $($subscription.Name)..." -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $subscription.Id | Out-Null
    
    try {
        # Activity log diagnostic settings are at subscription level
        $subscriptionResourceId = "/subscriptions/$($subscription.Id)"
        
        Write-Host "  Checking activity log diagnostic settings..." -ForegroundColor Cyan
        $settings = Get-AzDiagnosticSetting -ResourceId $subscriptionResourceId -ErrorAction SilentlyContinue
        
        if ($settings) {
            Write-Host "    Found diagnostic settings: $($settings.Name -join ', ')" -ForegroundColor Gray
        }
        else {
            Write-Host "    No diagnostic settings found" -ForegroundColor Gray
        }
        
        $targetSetting = $settings | Where-Object { $_.Name -eq $DiagnosticsSettingName }
        
        if ($targetSetting) {
            Write-Host "    Removing '$DiagnosticsSettingName'..." -ForegroundColor Yellow
            Remove-AzDiagnosticSetting -ResourceId $subscriptionResourceId -Name $DiagnosticsSettingName -ErrorAction Stop
            Write-Host "    ✓ Removed successfully" -ForegroundColor Green
            $totalRemoved++
        }
        else {
            Write-Host "    - Setting '$DiagnosticsSettingName' not found, skipping" -ForegroundColor Gray
            $totalSkipped++
        }
    }
    catch {
        Write-Host "    ✗ Failed to remove from subscription $($subscription.Name): $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan
Write-Host "Total Removed: $totalRemoved" -ForegroundColor Green
Write-Host "Total Skipped: $totalSkipped" -ForegroundColor Gray
