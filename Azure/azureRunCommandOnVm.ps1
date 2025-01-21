#Collects the VM's by calling the azureRunKql script
param(
	[bool]$runOnAllVms=$false,
	[string]$targetVmName,
	[string]$scriptPath = ".\azureRunKqlQuery.ps1", #You will need some tweaking to get this to work.
	[string]$scriptToRunOnVm='$env:COMPUTERNAME;systeminfo'
)

$resources = . $scriptPath

#.\genericLogonScript.ps1 -tenant "" #Run the generic logon script and see if we need to login. Only works if you add your tenantID between ""

if($resources -and $runOnAllVms){
	# This might take some monutes.. Be aware that you can change the throttle limit and timeout, but be clever...
	$Results = $resources | ForEach-Object -ThrottleLimit 100 -TimeoutSeconds 120 -Parallel {az vm run-command invoke --subscription $_.subscriptionId -g $_.resourceGroup -n $_.name --command-id RunPowerShellScript --scripts '$scriptToRunOnVm' | ConvertFrom-Json}
	$Results.value.message
} elseif($resources){
	# This might take some monutes.. Be aware that you can change the throttle limit and timeout, but be clever...
	$Results = $resources.where{$_.name -in ($targetVmName)} | ForEach-Object -ThrottleLimit 100 -TimeoutSeconds 120 -Parallel {az vm run-command invoke --subscription $_.subscriptionId -g $_.resourceGroup -n $_.name --command-id RunPowerShellScript --scripts '$scriptToRunOnVm' | ConvertFrom-Json}
	$Results.value.message
} else {
	write-host "No Resources could be found."
}