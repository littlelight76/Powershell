$mg = Get-AzManagementGroup
$prodScopes = $mg  | where-object -FilterScript { $_.name -like "*p*" }
$nonprodScopes = $mg | where-object -FilterScript { $_.name -like "*n*" }
$sharedScopes = $mg | where-object -FilterScript { $_.name -like "*s*" }

# Combine all scopes into one list
$combinedScopes = @()
$combinedScopes += $prodScopes
$combinedScopes += $nonprodScopes
$combinedScopes += $sharedScopes

# Output file path
$outputFile = ".\results.txt"

# Build output content - simple list of management group names only
$output = ""

foreach ($scope in $combinedScopes) {
    # Extract just the management group name from the Id path
    $mgName = ($scope.Id -split '/')[-1]
    $output += "$mgName`n"
}

# Save to file
$output | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "Results saved to: $outputFile" -ForegroundColor Green
Write-Host "Total Scopes: $($combinedScopes.Count)" -ForegroundColor Cyan
