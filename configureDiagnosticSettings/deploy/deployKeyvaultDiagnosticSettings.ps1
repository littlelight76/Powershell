param(
    [Parameter(Mandatory = $false)]
    [string]$KeyVaultName,
    
    [Parameter(Mandatory = $false)]
    [string]$WorkspaceResourceId = "/SUB01/resourcegroups/RG01/providers/microsoft.operationalinsights/workspaces/LAW001",
        
    [Parameter(Mandatory = $false)]
    [string]$DiagnosticsSettingName = "SOC",
    
    [Parameter(Mandatory = $false)]
    [bool]$AuditEventEnabled = $true
)

$list = Get-AzSubscription | Out-GridView -PassThru
$filteredSubscriptions = $list

# Error handling and logging
$ErrorActionPreference = "Stop"

# Summary counters
$totalProcessed = 0
$totalSuccess = 0
$totalFailed = 0
$failedItems = @()

try {
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Key Vault Diagnostic Settings Configuration" -ForegroundColor Cyan
    Write-Host "================================`n" -ForegroundColor Cyan
    
    # Get all subscriptions
    # Write-Host "Retrieving subscriptions..." -ForegroundColor Yellow
    # $allSubscriptions = Get-AzSubscription
    
    # # Filter subscriptions
    # $filteredSubscriptions = $allSubscriptions | Where-Object { 
    #     $name = $_.Name
    #     $SubscriptionFilter | ForEach-Object {
    #         if ($name -like $_) { return $true }
    #     }
    # }
    
    # if ($filteredSubscriptions.Count -eq 0) {
    #     Write-Host "No subscriptions found matching patterns: $($SubscriptionFilter -join ', ')" -ForegroundColor Yellow
    #     exit 0
    # }
    
    # Write-Host "Found $($filteredSubscriptions.Count) matching subscription(s):" -ForegroundColor Green
    # foreach ($sub in $filteredSubscriptions) {
    #     Write-Host "  - $($sub.Name) ($($sub.Id))" -ForegroundColor Gray
    # }
    # Write-Host ""
    
    # Loop through each subscription
    foreach ($subscription in $filteredSubscriptions) {
        Write-Host "`n==================== Processing Subscription: $($subscription.Name) ====================" -ForegroundColor Cyan
        
        try {
            # Set the subscription context
            Set-AzContext -SubscriptionId $subscription.Id | Out-Null
            Write-Host "Switched to subscription: $($subscription.Name)" -ForegroundColor Green
            
            # Get Key Vaults in this subscription
            $keyVaults = @()
            if ($KeyVaultName) {
                # Process specific Key Vault
                $kv = Get-AzKeyVault -VaultName $KeyVaultName -ErrorAction SilentlyContinue
                if ($kv) {
                    $keyVaults = @($kv)
                }
            }
            else {
                # Get all Key Vaults in subscription
                $keyVaults = Get-AzKeyVault
            }
            
            if ($keyVaults.Count -eq 0) {
                Write-Host "No Key Vaults found in subscription $($subscription.Name)" -ForegroundColor Yellow
                continue
            }
            
            Write-Host "Found $($keyVaults.Count) Key Vault(s) to process`n" -ForegroundColor Green
            
            # Process each Key Vault
            foreach ($keyVault in $keyVaults) {
                $totalProcessed++
                $kvName = $keyVault.VaultName
                
                Write-Host "`n--- Processing Key Vault: $kvName ---" -ForegroundColor Yellow
                
                try {
                    $keyVaultResourceId = $keyVault.ResourceId
                    Write-Host "Resource ID: $keyVaultResourceId" -ForegroundColor Gray
                    
                    # Check existing diagnostic settings
                    $existingSettings = Get-AzDiagnosticSetting -ResourceId $keyVaultResourceId -ErrorAction SilentlyContinue
                    
                    if ($existingSettings) {
                        Write-Host "Existing diagnostic settings found:" -ForegroundColor Yellow
                        foreach ($setting in $existingSettings) {
                            Write-Host "  - $($setting.Name)" -ForegroundColor Gray
                        }
                    }
                    else {
                        Write-Host "No existing diagnostic settings found" -ForegroundColor Gray
                    }
    
                    # Use the provided diagnostic setting name
                    $diagnosticSettingName = $DiagnosticsSettingName
                    
                    # Create log configuration objects based on enabled settings
                    $logs = @()
                    
                    if ($AuditEventEnabled) {
                        $logs += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category "AuditEvent"
                    }
                    
                    # Create metric configuration objects based on enabled settings
                    $metrics = @()
                    
                    if ($AllMetricsEnabled) {
                        $metrics += New-AzDiagnosticSettingMetricSettingsObject -Enabled $true -Category "AllMetrics"
                    }
                    
                    # Create or update diagnostic settings
                    Write-Host "Creating diagnostic setting '$diagnosticSettingName'..." -ForegroundColor Yellow
                    
                    # Build parameters for diagnostic setting
                    $diagnosticParams = @{
                        Name        = $diagnosticSettingName
                        ResourceId  = $keyVaultResourceId
                        WorkspaceId = $WorkspaceResourceId
                        ErrorAction = "Stop"
                    }
                    
                    # Add logs if any are enabled
                    if ($logs.Count -gt 0) {
                        $diagnosticParams['Log'] = $logs
                    }
                    
                    # Add metrics if enabled
                    if ($metrics.Count -gt 0) {
                        $diagnosticParams['Metric'] = $metrics
                    }
                    
                    New-AzDiagnosticSetting @diagnosticParams | Out-Null
                    
                    Write-Host "✓ Diagnostic settings enabled successfully for $kvName!" -ForegroundColor Green
                    $totalSuccess++
                    
                }
                catch {
                    Write-Host "✗ Failed to configure $kvName : $($_.Exception.Message)" -ForegroundColor Red
                    $totalFailed++
                    $failedItems += [PSCustomObject]@{
                        Subscription = $subscription.Name
                        KeyVault     = $kvName
                        Error        = $_.Exception.Message
                    }
                }
            }
            
        }
        catch {
            Write-Host "Error processing subscription $($subscription.Name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    # Summary report
    Write-Host "`n`n================================" -ForegroundColor Cyan
    Write-Host "Summary Report" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Total Key Vaults Processed: $totalProcessed" -ForegroundColor White
    Write-Host "Successfully Configured: $totalSuccess" -ForegroundColor Green
    Write-Host "Failed: $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "White" })
    Write-Host "`nConfiguration:" -ForegroundColor Cyan
    Write-Host "  Diagnostic Setting Name: $DiagnosticsSettingName" -ForegroundColor White
    Write-Host "  Workspace: $WorkspaceResourceId" -ForegroundColor White
    Write-Host "  AuditEvent: $AuditEventEnabled" -ForegroundColor White
    
    if ($failedItems.Count -gt 0) {
        Write-Host "`nFailed Items:" -ForegroundColor Red
        $failedItems | Format-Table -AutoSize
    }
    
}
catch {
    Write-Host "`nCritical Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.Exception.StackTrace)" -ForegroundColor Red
    exit 1
}
