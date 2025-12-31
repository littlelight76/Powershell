param(
    [Parameter(Mandatory = $false)]
    [string]$LogicAppName,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg01",

    [Parameter(Mandatory = $false)]
    [string]$WorkspaceResourceId = "/subscriptions/sub01/resourcegroups/rg01/providers/microsoft.operationalinsights/workspaces/law001",  

    [Parameter(Mandatory = $false)]
    [string]$DiagnosticsSettingName = "SOC"
    
    [Parameter(Mandatory = $false)]
    [bool]$LogsEnabled = $true,
    
    [Parameter(Mandatory = $false)]
    [bool]$AllMetricsEnabled = $true
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
    Write-Host "Logic App Diagnostic Settings Configuration" -ForegroundColor Cyan
    Write-Host "================================`n" -ForegroundColor Cyan
    
    # # Get all subscriptions
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
            
            # Get Logic Apps in this subscription
            $logicApps = @()
            if ($LogicAppName) {
                # Process specific Logic App
                if ($ResourceGroupName) {
                    $la = Get-AzLogicApp -ResourceGroupName $ResourceGroupName -Name $LogicAppName -ErrorAction SilentlyContinue
                    if ($la) {
                        $logicApps = @($la)
                    }
                }
                else {
                    # Search across all resource groups
                    $allResourceGroups = Get-AzResourceGroup
                    foreach ($rg in $allResourceGroups) {
                        $la = Get-AzLogicApp -ResourceGroupName $rg.ResourceGroupName -Name $LogicAppName -ErrorAction SilentlyContinue
                        if ($la) {
                            $logicApps = @($la)
                            break
                        }
                    }
                }
            }
            else {
                # Get all Logic Apps in subscription
                if ($ResourceGroupName) {
                    $logicApps = Get-AzLogicApp -ResourceGroupName $ResourceGroupName
                }
                else {
                    # Get all Logic Apps across all resource groups
                    $allResourceGroups = Get-AzResourceGroup
                    foreach ($rg in $allResourceGroups) {
                        $rgLogicApps = Get-AzLogicApp -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
                        if ($rgLogicApps) {
                            $logicApps += $rgLogicApps
                        }
                    }
                }
            }
            
            if ($logicApps.Count -eq 0) {
                Write-Host "No Logic Apps found in subscription $($subscription.Name)" -ForegroundColor Yellow
                continue
            }
            
            Write-Host "Found $($logicApps.Count) Logic App(s) to process`n" -ForegroundColor Green
            
            # Process each Logic App
            foreach ($logicApp in $logicApps) {
                $totalProcessed++
                $laName = $logicApp.Name
                
                Write-Host "`n--- Processing Logic App: $laName ---" -ForegroundColor Yellow
                
                try {
                    $logicAppResourceId = $logicApp.Id
                    Write-Host "Resource ID: $logicAppResourceId" -ForegroundColor Gray
                    
                    # Check existing diagnostic settings
                    $existingSettings = Get-AzDiagnosticSetting -ResourceId $logicAppResourceId -ErrorAction SilentlyContinue
                    
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
                    # Logic Apps available log categories: WorkflowRuntime
                    $logs = @()
                    
                    if ($LogsEnabled) {
                        $logs += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category "WorkflowRuntime"
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
                        ResourceId  = $logicAppResourceId
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
                    
                    Write-Host "✓ Diagnostic settings enabled successfully for $laName!" -ForegroundColor Green
                    $totalSuccess++
                    
                }
                catch {
                    Write-Host "✗ Failed to configure $laName : $($_.Exception.Message)" -ForegroundColor Red
                    $totalFailed++
                    $failedItems += [PSCustomObject]@{
                        Subscription  = $subscription.Name
                        LogicApp      = $laName
                        ResourceGroup = $logicApp.ResourceGroupName
                        Error         = $_.Exception.Message
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
    Write-Host "Total Logic Apps Processed: $totalProcessed" -ForegroundColor White
    Write-Host "Successfully Configured: $totalSuccess" -ForegroundColor Green
    Write-Host "Failed: $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "White" })
    Write-Host "`nConfiguration:" -ForegroundColor Cyan
    Write-Host "  Diagnostic Setting Name: $DiagnosticsSettingName" -ForegroundColor White
    Write-Host "  Workspace: $WorkspaceResourceId" -ForegroundColor White
    Write-Host "  Logs Enabled (WorkflowRuntime): $LogsEnabled" -ForegroundColor White
    Write-Host "  Metrics Enabled (AllMetrics): $AllMetricsEnabled" -ForegroundColor White
    
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

# Example usage:
# Process all Logic Apps in subscriptions starting with az111 or az112:
# .\diagnosticSettingsLogicApp.ps1
#
# Process a specific Logic App across matching subscriptions:
# .\diagnosticSettingsLogicApp.ps1 -LogicAppName "myLogicApp"
#
# Process Logic Apps in a specific resource group:
# .\diagnosticSettingsLogicApp.ps1 -ResourceGroupName "myResourceGroup"
#
# Custom configuration:
# .\diagnosticSettingsLogicApp.ps1 -LogsEnabled $true -MetricsEnabled $true
