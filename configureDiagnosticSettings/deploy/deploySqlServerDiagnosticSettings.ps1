param(
    [Parameter(Mandatory = $false)]
    [string]$SqlServerName,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$WorkspaceResourceId = "/subscriptions/sub01/resourcegroups/rg01/providers/microsoft.operationalinsights/workspaces/law001",

    [Parameter(Mandatory = $false)]
    [string]$DiagnosticsSettingName = "SOC",
    
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
    Write-Host "Azure SQL Server Diagnostic Settings Configuration" -ForegroundColor Cyan
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
           
            # Get SQL Servers in this subscription
            $sqlServers = @()
            if ($SqlServerName) {
                # Process specific SQL Server
                if ($ResourceGroupName) {
                    $server = Get-AzSqlServer -ResourceGroupName $ResourceGroupName -ServerName $SqlServerName -ErrorAction SilentlyContinue
                    if ($server) {
                        $sqlServers = @($server)
                    }
                }
                else {
                    # Search across all resource groups
                    $allResourceGroups = Get-AzResourceGroup
                    foreach ($rg in $allResourceGroups) {
                        $server = Get-AzSqlServer -ResourceGroupName $rg.ResourceGroupName -ServerName $SqlServerName -ErrorAction SilentlyContinue
                        if ($server) {
                            $sqlServers = @($server)
                            break
                        }
                    }
                }
            }
            else {
                # Get all SQL Servers in subscription
                if ($ResourceGroupName) {
                    $sqlServers = Get-AzSqlServer -ResourceGroupName $ResourceGroupName
                }
                else {
                    # Get all SQL Servers across all resource groups
                    $allResourceGroups = Get-AzResourceGroup
                    foreach ($rg in $allResourceGroups) {
                        $rgSqlServers = Get-AzSqlServer -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
                        if ($rgSqlServers) {
                            $sqlServers += $rgSqlServers
                        }
                    }
                }
            }
            
            if ($sqlServers.Count -eq 0) {
                Write-Host "No SQL Servers found in subscription $($subscription.Name)" -ForegroundColor Yellow
                continue
            }
            
            Write-Host "Found $($sqlServers.Count) SQL Server(s) to process`n" -ForegroundColor Green
            
            # Process each SQL Server
            foreach ($sqlServer in $sqlServers) {
                $totalProcessed++
                $serverName = $sqlServer.ServerName
                
                Write-Host "`n--- Processing SQL Server: $serverName ---" -ForegroundColor Yellow
                
                try {
                    # SQL Server resource ID (type: microsoft.sql/servers)
                    $sqlServerResourceId = $sqlServer.ResourceId
                    Write-Host "Resource ID: $sqlServerResourceId" -ForegroundColor Gray
                    
                    # Check existing diagnostic settings
                    $existingSettings = Get-AzDiagnosticSetting -ResourceId $sqlServerResourceId -ErrorAction SilentlyContinue
                    
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
                    
                    # SQL Server resources (microsoft.sql/servers) only support metrics, not log categories
                    # Create metric configuration objects based on enabled settings
                    $metrics = @()
                    
                    if ($AllMetricsEnabled) {
                        Write-Host "Enabling AllMetrics" -ForegroundColor Yellow
                        $metrics += New-AzDiagnosticSettingMetricSettingsObject -Enabled $true -Category "AllMetrics" -RetentionPolicyDay 0 -RetentionPolicyEnabled $false
                    }
                    
                    if ($metrics.Count -eq 0) {
                        Write-Host "⚠ Warning: No metrics enabled, skipping $serverName" -ForegroundColor Yellow
                        continue
                    }
                    
                    # Create or update diagnostic settings
                    Write-Host "Creating diagnostic setting '$diagnosticSettingName'..." -ForegroundColor Yellow
                    
                    # Build parameters for diagnostic setting
                    $diagnosticParams = @{
                        Name        = $diagnosticSettingName
                        ResourceId  = $sqlServerResourceId
                        WorkspaceId = $WorkspaceResourceId
                        Metric      = $metrics
                        ErrorAction = "Stop"
                    }
                    
                    New-AzDiagnosticSetting @diagnosticParams | Out-Null
                    
                    Write-Host "✓ Diagnostic settings enabled successfully for SQL Server: $serverName!" -ForegroundColor Green
                    $totalSuccess++
                    
                }
                catch {
                    Write-Host "✗ Failed to configure $serverName : $($_.Exception.Message)" -ForegroundColor Red
                    $totalFailed++
                    $failedItems += [PSCustomObject]@{
                        Subscription  = $subscription.Name
                        SqlServer     = $serverName
                        ResourceGroup = $sqlServer.ResourceGroupName
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
    Write-Host "Total SQL Servers Processed: $totalProcessed" -ForegroundColor White
    Write-Host "Successfully Configured: $totalSuccess" -ForegroundColor Green
    Write-Host "Failed: $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "White" })
    Write-Host "`nConfiguration:" -ForegroundColor Cyan
    Write-Host "  Diagnostic Setting Name: $DiagnosticsSettingName" -ForegroundColor White
    Write-Host "  Workspace: $WorkspaceResourceId" -ForegroundColor White
    
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
# Process all SQL Servers across matching subscriptions:
# .\diagnosticSettingsSqlServer.ps1
#
# Process a specific SQL Server:
# .\diagnosticSettingsSqlServer.ps1 -SqlServerName "mySqlServer"
#
# Process SQL Servers in a specific resource group:
# .\diagnosticSettingsSqlServer.ps1 -ResourceGroupName "myResourceGroup"
