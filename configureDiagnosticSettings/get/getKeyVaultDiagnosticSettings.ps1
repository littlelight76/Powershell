$list = Get-AzSubscription | Out-GridView -PassThru
$filteredSubscriptions = $list

Write-Host "================================" -ForegroundColor Cyan
Write-Host "Key Vault Diagnostic Settings List" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$results = @()
Write-Host "Retrieving subscriptions..." -ForegroundColor Yellow

Write-Host "Found $($filteredSubscriptions.Count) matching subscription(s)`n" -ForegroundColor Green

foreach ($subscription in $filteredSubscriptions) {
    Write-Host "Processing: $($subscription.Name)..." -ForegroundColor Yellow
    Set-AzContext -SubscriptionId $subscription.Id | Out-Null
    
    $keyVaults = Get-AzKeyVault -ErrorAction SilentlyContinue
    Write-Host "  Found $($keyVaults.Count) Key Vault(s)" -ForegroundColor Gray
    
    foreach ($keyVault in $keyVaults) {
        $settings = Get-AzDiagnosticSetting -ResourceId $keyVault.ResourceId -ErrorAction SilentlyContinue
        
        $results += [PSCustomObject]@{
            Subscription      = $subscription.Name
            ResourceGroup     = $keyVault.ResourceGroupName
            KeyVaultName      = $keyVault.VaultName
            DiagnosticSetting = if ($settings) { ($settings.Name -join ', ') } else { "None" }
        }
    }
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Results" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

$results | Format-Table -AutoSize
