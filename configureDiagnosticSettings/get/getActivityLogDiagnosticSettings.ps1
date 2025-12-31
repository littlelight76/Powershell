$list = Get-AzSubscription | Out-GridView -PassThru
$filteredSubscriptions = $list

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Activity Log Diagnostic Settings List" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$results = @()
Write-Host "Retrieving subscriptions..." -ForegroundColor Yellow

Write-Host "Found $($filteredSubscriptions.Count) matching subscription(s)`n" -ForegroundColor Green

foreach ($subscription in $filteredSubscriptions) {
    Write-Host "Processing: $($subscription.Name)..." -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $subscription.Id | Out-Null
    
    # Activity Log diagnostic settings are at the subscription level
    $subscriptionResourceId = "/subscriptions/$($subscription.Id)"
    $settings = Get-AzDiagnosticSetting -ResourceId $subscriptionResourceId -ErrorAction SilentlyContinue
    
    $results += [PSCustomObject]@{
        Subscription      = $subscription.Name
        SubscriptionId    = $subscription.Id
        DiagnosticSetting = if ($settings) { ($settings.Name -join ', ') } else { "None" }
    }
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Results" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$results | Format-Table -AutoSize
