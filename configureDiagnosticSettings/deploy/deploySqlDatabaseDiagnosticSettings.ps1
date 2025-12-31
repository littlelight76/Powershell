param(
    [Parameter(Mandatory = $false)]
    [string]$SqlServerName,
    
    [Parameter(Mandatory = $false)]
    [string]$DatabaseName,
    
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$WorkspaceResourceId = "/subscriptions/sub01/resourcegroups/rg01/providers/microsoft.operationalinsights/workspaces/law001",

    [Parameter(Mandatory = $false)]
    [string]$DiagnosticsSettingName = "SOC",
    
    # Log category parameters (matching policy definition) 
    [Parameter(Mandatory = $false)]
    [bool]$SqlSecurityAuditEventsEnabled = $true    
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
    Write-Host "Azure SQL Database Diagnostic Settings Configuration" -ForegroundColor Cyan
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
            
            # Process each SQL Server and its databases
            foreach ($sqlServer in $sqlServers) {
                $serverName = $sqlServer.ServerName
                
                Write-Host "`n--- Processing SQL Server: $serverName ---" -ForegroundColor Cyan
                
                try {
                    # Get databases on this SQL Server
                    $databases = @()
                    if ($DatabaseName) {
                        # Process specific database
                        $db = Get-AzSqlDatabase -ResourceGroupName $sqlServer.ResourceGroupName -ServerName $serverName -DatabaseName $DatabaseName -ErrorAction SilentlyContinue
                        if ($db) {
                            $databases = @($db)
                        }
                    }
                    else {
                        # Get all databases on this server
                        $databases = Get-AzSqlDatabase -ResourceGroupName $sqlServer.ResourceGroupName -ServerName $serverName -ErrorAction SilentlyContinue
                    }
                    
                    if ($databases.Count -eq 0) {
                        Write-Host "No databases found on SQL Server: $serverName" -ForegroundColor Yellow
                        continue
                    }
                    
                    Write-Host "Found $($databases.Count) database(s) on server: $serverName" -ForegroundColor Green
                    
                    # Process each database
                    foreach ($database in $databases) {
                        $totalProcessed++
                        $dbName = $database.DatabaseName
                        
                        Write-Host "`n  --- Processing Database: $dbName ---" -ForegroundColor Yellow
                        
                        try {
                            # Resource ID format: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Sql/servers/{server}/databases/{database}
                            $databaseResourceId = $database.ResourceId
                            Write-Host "  Resource ID: $databaseResourceId" -ForegroundColor Gray
                            
                            # Check existing diagnostic settings
                            $existingSettings = Get-AzDiagnosticSetting -ResourceId $databaseResourceId -ErrorAction SilentlyContinue
                            
                            if ($existingSettings) {
                                Write-Host "  Existing diagnostic settings found:" -ForegroundColor Yellow
                                foreach ($setting in $existingSettings) {
                                    Write-Host "    - $($setting.Name)" -ForegroundColor Gray
                                }
                            }
                            else {
                                Write-Host "  No existing diagnostic settings found" -ForegroundColor Gray
                            }
            
                            # Use the provided diagnostic setting name
                            $diagnosticSettingName = $DiagnosticsSettingName
                            
                            # Create log configuration objects based on enabled settings
                            $logs = @()
                            
                            if ($SqlSecurityAuditEventsEnabled) {
                                $logs += New-AzDiagnosticSettingLogSettingsObject -Enabled $true -Category "SQLSecurityAuditEvents" -RetentionPolicyDay 0 -RetentionPolicyEnabled $false
                            }
                           
                            # Check if at least one log or metric is enabled
                            if ($logs.Count -eq 0) {
                                Write-Host "  ⚠ Warning: No logs enabled for $dbName, skipping..." -ForegroundColor Yellow
                                continue
                            }
                            
                            # Create or update diagnostic settings
                            Write-Host "  Creating diagnostic setting '$diagnosticSettingName'..." -ForegroundColor Yellow
                            
                            # Build parameters for diagnostic setting
                            $diagnosticParams = @{
                                Name        = $diagnosticSettingName
                                ResourceId  = $databaseResourceId
                                WorkspaceId = $WorkspaceResourceId
                                ErrorAction = "Stop"
                            }
                            
                            # Add logs if any are enabled
                            if ($logs.Count -gt 0) {
                                $diagnosticParams['Log'] = $logs
                            }
                            
                            New-AzDiagnosticSetting @diagnosticParams | Out-Null
                            
                            Write-Host "  ✓ Diagnostic settings enabled successfully for database: $dbName!" -ForegroundColor Green
                            $totalSuccess++
                            
                        }
                        catch {
                            Write-Host "  ✗ Failed to configure database $dbName : $($_.Exception.Message)" -ForegroundColor Red
                            $totalFailed++
                            $failedItems += [PSCustomObject]@{
                                Subscription  = $subscription.Name
                                SqlServer     = $serverName
                                Database      = $dbName
                                ResourceGroup = $sqlServer.ResourceGroupName
                                Error         = $_.Exception.Message
                            }
                        }
                    }
                    
                }
                catch {
                    Write-Host "✗ Error processing SQL Server $serverName : $($_.Exception.Message)" -ForegroundColor Red
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
    Write-Host "Total SQL Databases Processed: $totalProcessed" -ForegroundColor White
    Write-Host "Successfully Configured: $totalSuccess" -ForegroundColor Green
    Write-Host "Failed: $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "White" })
    Write-Host "`nConfiguration:" -ForegroundColor Cyan
    Write-Host "  Diagnostic Setting Name: $DiagnosticsSettingName" -ForegroundColor White
    Write-Host "  Workspace: $WorkspaceResourceId" -ForegroundColor White
    Write-Host "`n  Enabled Log Categories:" -ForegroundColor Cyan
    Write-Host "    SQLSecurityAuditEvents: $SqlSecurityAuditEventsEnabled" -ForegroundColor White
    
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
# Process all SQL Databases with default settings (SQLSecurityAuditEvents only):
# .\diagnosticSettingsSqlDatabase.ps1
#
# Process all databases on a specific SQL Server:
# .\diagnosticSettingsSqlDatabase.ps1 -SqlServerName "mySqlServer"
#
# Process a specific database:
# .\diagnosticSettingsSqlDatabase.ps1 -SqlServerName "mySqlServer" -DatabaseName "myDatabase"
#
# Enable additional log categories:
# .\diagnosticSettingsSqlDatabase.ps1 -ErrorsEnabled $true -DeadlocksEnabled $true -TimeoutsEnabled $true
#
# Enable metrics:
# .\diagnosticSettingsSqlDatabase.ps1 -BasicMetricsEnabled $true
