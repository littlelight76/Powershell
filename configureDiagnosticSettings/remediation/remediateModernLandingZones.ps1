# Remediate the policy assignment for deploying diagnostic logs to Log Analytics Workspace
# https://learn.microsoft.com/en-us/powershell/module/az.policyinsights/start-azpolicyremediation?view=azps-15.1.0

# Read management groups from results.txt
$managementGroups = Get-Content -Path ".\results.txt"

# Define the policy definition reference IDs from the policy set
$policyReferenceIds = @(
    "deployActivityLogDiagnosticSettings",
    "deployAzureSqlServerDiagnosticSettings",
    "deployKeyVaultDiagnosticSettings",
    "deploySqlDatabaseDiagnosticSettings"
)

Write-Host "Starting remediation for $($managementGroups.Count) management groups..." -ForegroundColor Cyan
Write-Host "Remediating $($policyReferenceIds.Count) policies per management group`n" -ForegroundColor Cyan

# Initialize counters and tracking arrays
$successCount = 0
$failCount = 0
$failedRemediations = @()

# Set error action preference to stop so try-catch works properly
$ErrorActionPreference = "Stop"

# Loop through each management group
foreach ($mg in $managementGroups) {
    Write-Host "`n================================" -ForegroundColor Cyan
    Write-Host "Processing management group: $mg" -ForegroundColor Yellow
    Write-Host "================================" -ForegroundColor Cyan
    
    $policyAssignmentId = "/providers/Microsoft.Management/managementGroups/$mg/providers/Microsoft.Authorization/policyAssignments/soc"
    
    # Remediate each policy in the policy set
    foreach ($policyRefId in $policyReferenceIds) {
        Write-Host "  Remediating: $policyRefId" -ForegroundColor Gray
        
        try {
            Start-AzPolicyRemediation -ManagementGroupName $mg `
                -PolicyAssignmentId $policyAssignmentId `
                -PolicyDefinitionReferenceId $policyRefId `
                -Name "[SCSC-SOC] $mg - $policyRefId" `
                -LocationFilter "westeurope" `
                -ErrorAction Stop
            Write-Host "    ✓ Success" -ForegroundColor Green
            $successCount++
        }
        catch {
            Write-Host "    ✗ Failed: $($_.Exception.Message)" -ForegroundColor Red
            $failCount++
            $failedRemediations += [PSCustomObject]@{
                ManagementGroup = $mg
                PolicyReferenceId = $policyRefId
                Error = $_.Exception.Message
            }
        }
    }
}

Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "Remediation Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Total Management Groups: $($managementGroups.Count)" -ForegroundColor White
Write-Host "Total Policies per MG: $($policyReferenceIds.Count)" -ForegroundColor White
Write-Host "Total Remediation Tasks: $($managementGroups.Count * $policyReferenceIds.Count)" -ForegroundColor White
Write-Host "Succeeded: $successCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor Red

if ($failCount -gt 0) {
    Write-Host "`nFailed Remediations:" -ForegroundColor Yellow
    $failedRemediations | Format-Table -AutoSize ManagementGroup, PolicyReferenceId
}
Write-Host "================================`n" -ForegroundColor Cyan
