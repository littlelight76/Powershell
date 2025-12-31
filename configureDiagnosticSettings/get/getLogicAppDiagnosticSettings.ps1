$list = Get-AzSubscription | Out-GridView -PassThru
$filteredSubscriptions = $list

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Logic App Diagnostic Settings List" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$results = @()
Write-Host "Retrieving subscriptions..." -ForegroundColor Yellow

Write-Host "Found $($filteredSubscriptions.Count) matching subscription(s)`n" -ForegroundColor Green

foreach ($subscription in $filteredSubscriptions) {
    Write-Host "Processing: $($subscription.Name)..." -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $subscription.Id | Out-Null
    
    $logicApps = Get-AzLogicApp -ErrorAction SilentlyContinue
    Write-Host "  Found $($logicApps.Count) Logic App(s)" -ForegroundColor Gray
    
    foreach ($logicApp in $logicApps) {
        $settings = Get-AzDiagnosticSetting -ResourceId $logicApp.Id -ErrorAction SilentlyContinue
        
        $results += [PSCustomObject]@{
            Subscription      = $subscription.Name
            ResourceGroup     = $logicApp.ResourceGroupName
            LogicAppName      = $logicApp.Name
            DiagnosticSetting = if ($settings) { ($settings.Name -join ', ') } else { "None" }
        }
    }
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Results" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$results | Format-Table -AutoSize
