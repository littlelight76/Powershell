$list = Get-AzSubscription | Out-GridView -PassThru
$filteredSubscriptions = $list

Write-Host "================================" -ForegroundColor Cyan
Write-Host "SQL Server Diagnostic Settings List" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$results = @()
Write-Host "Retrieving subscriptions..." -ForegroundColor Yellow

Write-Host "Found $($filteredSubscriptions.Count) matching subscription(s)`n" -ForegroundColor Green

foreach ($subscription in $filteredSubscriptions) {
    Write-Host "Processing: $($subscription.Name)..." -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $subscription.Id | Out-Null
    
    $sqlServers = Get-AzSqlServer -ErrorAction SilentlyContinue
    Write-Host "  Found $($sqlServers.Count) SQL Server(s)" -ForegroundColor Gray
    
    foreach ($sqlServer in $sqlServers) {
        $settings = Get-AzDiagnosticSetting -ResourceId $sqlServer.ResourceId -ErrorAction SilentlyContinue
        
        $results += [PSCustomObject]@{
            Subscription      = $subscription.Name
            ResourceGroup     = $sqlServer.ResourceGroupName
            ServerName        = $sqlServer.ServerName
            DiagnosticSetting = if ($settings) { ($settings.Name -join ', ') } else { "None" }
        }
    }
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Results" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$results | Format-Table -AutoSize     