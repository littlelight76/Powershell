Context
Existing Azure Policies in Classic Landing Zone have been assigned to an old Log Analytic Workspace.
This was assigned via Azure Portal and now, these existing policies are assigned through EPAC-Classic-LZ (This repository) with the new Log Analytic Workspace.

However, due to the existing Azure BuiltIn Policies, the affected resources must be configured manually since it will not trigger the DeployIfNotExist (configure Diagnostic Settings to the new Log Analytic Workspace) due to the policy definition code statement (if logs are generated, (which they are), deploy it).
Therefore, the current diagnostic settings must be identified (find if the Azure resource has enabled Diagnostic Settings and if so, what is the name of it).
If a name is discovered, remove it all deploy new diagnostic settings for those resources (including resources where no Diagnostic Settings has been configured).

Note: It is not allowed to deploy multiple Diagnostic Settings if it uses the same Logs Settings category (hence the config needs to be removed first).

File Structure

- Deploy: Deploy Diagnostic Settings to Azure Resources (not really needed since this can be done by Remediation task since it is DeployIfNotExists policy).
- Get: Get a list of affected resource and see what the current Diagnostic Settings are.
- Remediation: Remediate all Policies in the Policy Assignments based on the getManagementGroups.ps1 scope.
- Remove: Remove old Diagnostic Settings (use case for this was that current setting was forwarding logs to old LAW)
