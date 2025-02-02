<#
	This is a script to easily (manually) upgrade all your clusters using script. You could just select 1 to start with though
	Lets login first, then run 

#>
param(
	[bool]$local=$true,
	[string]$subscription,
	[string]$aksVer=1.30.5,
	[bool]$runAll=$false,
	[string]$clusterName,
	[bool]$force=$false
)
if($local){
	#Set the path to the login script correctly
	. "..\genericLogonScript.ps1"
}
if (-not $runAll){
	aksList = az aks list --subscription $subscription
	$aksList = $aksList | ConvertFrom-Json
	$aks = $aksList | Where-Object {$_.name -eq $clusterName}
	if($force){
		az aks upgrade --subscription $subscription --resource-group $aks.resourceGroup --name $aks.name --kubernetes-version $aksVer --enable-force-upgrade --no-wait
	} else {
		az aks upgrade --subscription $subscription --resource-group $aks.resourceGroup --name $aks.name --kubernetes-version $aksVer
	}
} else {
	$aksList = az aks list --subscription $subscription
	$aksList = $aksList | ConvertFrom-Json

	foreach ($aks in $aksList){
		if($force){
			az aks upgrade --subscription $subscription --resource-group $aks.resourceGroup --name $aks.name --kubernetes-version $kubernetesVersion --enable-force-upgrade --no-wait
		} else {
			az aks upgrade --subscription $subscription --resource-group $aks.resourceGroup --name $aks.name --kubernetes-version $kubernetesVersion
		}
	}
}