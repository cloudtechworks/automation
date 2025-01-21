<#
	This script will allow you to run KQL queries using Powershell 
	You can run these queries either locally by setting your kql file path
	IF kqlFilePath is EMPTY it will run the query you provided in resourceQuery.
	IF kqlFilePath is set correctly it will IGNORE the resourceQuery parameter, and use your kqlFilePath to extract the query from KQL
#>
param(
	[string]$kqlFilePath = ".\resourceGraphQueries\listVm.kql", #Enter the path to your KQL query
	[string]$resourceQuery = "resources | where type =~ 'Microsoft.Compute/virtualMachines' | project name" # Replace with your query
)
if($kqlFilePath){
	$fileContent = Get-Content -Path $kqlFilePath -Raw
	$lines = $fileContent -split [Environment]::NewLine
	$resourceQuery = $lines -join " "
} else {
	Write-Host "Proceeding by using the basic KQL query given here: $resourceQuery"
}
#.\genericLogonScript.ps1 -tenant "" #Run the generic logon script and see if we need to login. Only works if you add your tenantID between ""
# Execute the query and process the results, be aware you might need to login to get the data
(az graph query --first 1000 -q $resourceQuery | ConvertFrom-Json).data