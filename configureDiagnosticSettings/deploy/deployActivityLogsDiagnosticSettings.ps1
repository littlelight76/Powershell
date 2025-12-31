param(
    [Parameter(Mandatory = $false)]
    [string]$WorkspaceResourceId = "/subscriptions/sub01/resourcegroups/rg01/providers/microsoft.operationalinsights/workspaces/LAW001",
    
    [Parameter(Mandatory = $false)]
    [string]$DiagnosticsSettingName = "SOC",
    
    [Parameter(Mandatory = $false)]
    [bool]$LogsEnabled = $true
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

# Activity Log categories available in Azure
$activityLogCategories = @(
    "Administrative",
    "Security",
    "ServiceHealth",
    "Alert",
    "Recommendation",
    "Policy",
    "ResourceHealth"
)

try {
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Activity Log Diagnostic Settings Configuration" -ForegroundColor Cyan
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
        $totalProcessed++
        
        try {
            # Set the subscription context
            Set-AzContext -SubscriptionId $subscription.Id | Out-Null
            Write-Host "Switched to subscription: $($subscription.Name)" -ForegroundColor Green
            
            # Activity Log diagnostic settings are at subscription level
            # Resource ID format for subscription activity logs
            $subscriptionResourceId = "/subscriptions/$($subscription.Id)"
            
            Write-Host "`nConfiguring Activity Log diagnostic settings..." -ForegroundColor Yellow
            Write-Host "Subscription Resource ID: $subscriptionResourceId" -ForegroundColor Gray
            
            # Check existing diagnostic settings
            $existingSettings = Get-AzDiagnosticSetting -ResourceId $subscriptionResourceId -ErrorAction SilentlyContinue
            
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
            
            # Create log configuration objects for all Activity Log categories
            $logs = @()
            
            if ($LogsEnabled) {
                Write-Host "`nEnabling Activity Log categories:" -ForegroundColor Yellow
                foreach ($category in $activityLogCategories) {
                    Write-Host "  - $category" -ForegroundColor Gray
                    $logs += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category $category
                }
            }
            
            # Create or update diagnostic settings
            Write-Host "`nCreating diagnostic setting '$diagnosticSettingName'..." -ForegroundColor Yellow
            
            # Build parameters for diagnostic setting
            $diagnosticParams = @{
                Name        = $diagnosticSettingName
                ResourceId  = $subscriptionResourceId
                WorkspaceId = $WorkspaceResourceId
                ErrorAction = "Stop"
            }
            
            # Add logs if enabled
            if ($logs.Count -gt 0) {
                $diagnosticParams['Log'] = $logs
            }
            
            New-AzDiagnosticSetting @diagnosticParams | Out-Null
            
            Write-Host "✓ Activity Log diagnostic settings enabled successfully for subscription: $($subscription.Name)!" -ForegroundColor Green
            $totalSuccess++
            
        }
        catch {
            Write-Host "✗ Failed to configure Activity Log for subscription $($subscription.Name): $($_.Exception.Message)" -ForegroundColor Red
            $totalFailed++
            $failedItems += [PSCustomObject]@{
                Subscription   = $subscription.Name
                SubscriptionId = $subscription.Id
                Error          = $_.Exception.Message
            }
        }
    }
    
    # Summary report
    Write-Host "`n`n================================" -ForegroundColor Cyan
    Write-Host "Summary Report" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "Total Subscriptions Processed: $totalProcessed" -ForegroundColor White
    Write-Host "Successfully Configured: $totalSuccess" -ForegroundColor Green
    Write-Host "Failed: $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "White" })
    Write-Host "`nConfiguration:" -ForegroundColor Cyan
    Write-Host "  Diagnostic Setting Name: $DiagnosticsSettingName" -ForegroundColor White
    Write-Host "  Workspace: $WorkspaceResourceId" -ForegroundColor White
    Write-Host "  Logs Enabled: $LogsEnabled" -ForegroundColor White
    
    if ($LogsEnabled) {
        Write-Host "`n  Activity Log Categories Enabled:" -ForegroundColor Cyan
        foreach ($category in $activityLogCategories) {
            Write-Host "    - $category" -ForegroundColor Gray
        }
    }
    
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
# Process all subscriptions starting with az111 or az112:
# .\diagnosticSettingsActivityLogs.ps1
#
# Disable logs:
# .\diagnosticSettingsActivityLogs.ps1 -LogsEnabled $false
#
# Custom subscription filter:
# .\diagnosticSettingsActivityLogs.ps1 -SubscriptionFilter @("prod*", "dev*")
