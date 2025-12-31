$list = Get-AzSubscription | Out-GridView -PassThru
$filteredSubscriptions = $list

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Remove SQL Database Diagnostic Settings 'SCSC-Logs'" -ForegroundColor Cyan
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
        $databases = Get-AzSqlDatabase -ServerName $sqlServer.ServerName -ResourceGroupName $sqlServer.ResourceGroupName -ErrorAction SilentlyContinue | Where-Object { $_.DatabaseName -ne "master" }
        Write-Host "    Server: $($sqlServer.ServerName) - Found $($databases.Count) database(s)" -ForegroundColor Gray
        
        foreach ($database in $databases) {
            try {
                $settings = Get-AzDiagnosticSetting -ResourceId $database.ResourceId -ErrorAction SilentlyContinue
                
                $targetSetting = $settings | Where-Object { $_.Name -eq $DiagnosticsSettingName }
                
                if ($targetSetting) {
                    Write-Host "      Removing '$DiagnosticsSettingName' from $($database.DatabaseName)..." -ForegroundColor Yellow
                    Remove-AzDiagnosticSetting -ResourceId $database.ResourceId -Name $DiagnosticsSettingName -ErrorAction Stop
                    Write-Host "      ✓ Removed successfully" -ForegroundColor Green
                    $totalRemoved++
                }
                else {
                    Write-Host "      - $($database.DatabaseName): Setting not found, skipping" -ForegroundColor Gray
                    $totalSkipped++
                }
            }
            catch {
                Write-Host "      ✗ Failed to remove from $($database.DatabaseName): $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan
Write-Host "Total Removed: $totalRemoved" -ForegroundColor Green
Write-Host "Total Skipped: $totalSkipped" -ForegroundColor Gray
