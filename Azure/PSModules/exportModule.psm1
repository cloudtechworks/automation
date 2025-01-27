function ExportTo-Bicep
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $true)]
		[bool]$OnSubscriptionLevel,
		[Parameter(Mandatory = $true)]
		[string]$Subscription,
		[array]$ResourceTypes,
		[string]$ResourceGroupName,
		[array]$ResourceGroupNameList,
		[string]$VNetName,
		[array]$VNetNameList,
		[string]$Location,
		[array]$SubnetName,
		[string]$PublicIpName,
		[array]$PublicIpNameList,
		[string]$ExportFileName = "$($Subscription)_combined_resources"
	)
	#Setting the az context to the subscription:
	Set-AzContext -Subscription $Subscription
	if (-not $OnSubscriptionLevel)
	{
		if ('ResourceGroup' -in $ResourceTypes -and $ResourceGroupName)
		{
			$rg = Get-AzResourceGroup -Name $ResourceGroupName
			$tags = if ($null -ne $rg.Tags) { GenerateTagsBicepBlock -Tags $rg.Tags }
			else { '{}' }
			$bicepTemplateContent += @"
param resourceGroupName string
param location string
param tags object

resource rg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
}
"@
			$bicepParamsContent += @"
using '$ExportFileName.bicep'

param resourceGroupName = '$ResourceGroupName'

param location = '$($rg.location)'

"@
		}
		if ('VNet' -in $ResourceTypes -and $VNetName)
		{
			$vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
			$addressPrefixes = $vnet.AddressSpace.AddressPrefixes -join "', '"

			$tags = if ($null -ne $vnet.Tags) { GenerateTagsBicepBlock -Tags $vnet.Tags }
			else { '{}' }
			
			$bicepTemplateContent += @"
param vnetName string
param addressPrefixes array
param tags object

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-02-01' = {
  name: vnetName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
  }
}
"@
			$bicepParamsContent += @"
param vnetName = '$VNetName'

param addressPrefixes
  '$addressPrefixes'
]

"@
		}
		
		if ('PublicIP' -in $ResourceTypes -and $PublicIpName)
		{
			$publicIp = Get-AzPublicIpAddress -Name $PublicIpName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
			$dnsLabel = $publicIp.DnsSettings.DomainNameLabel
			$skuName = $publicIp.Sku.Name
			$skuTier = $publicIp.Sku.Tier
			$ipVersion = $publicIp.IpAddressVersion
			$allocationMethod = $publicIp.PublicIpAllocationMethod
			$idleTimeout = $publicIp.IdleTimeoutInMinutes
			$zones = $publicIp.Zones -join "', '"
			
			# Optional properties
			$ddosPlanId = if ($null -ne $publicIp.DdosSettings) { $publicIp.DdosSettings.DdosProtectionPlanId }
			else { '' }
			$ddosMode = if ($null -ne $publicIp.DdosSettings) { $publicIp.DdosSettings.ProtectionMode }
			else { '' }
			$natGatewayId = if ($null -ne $publicIp.NatGateway) { $publicIp.NatGateway.Id }
			else { '' }
			$tags = if ($null -ne $publicIp.Tags) { GenerateTagsBicepBlock -Tags $publicIp.Tags }
			else { '{}' }
			
			$bicepTemplateContent += @"
param publicIpName string
param domainNameLabel string
param skuName string
param skuTier string
param ipVersion string
param allocationMethod string
param idleTimeout int
param zones array
param tags object
"@
			
			$bicepParamsContent += @"
param publicIpName = '$PublicIpName'
param domainNameLabel = '$dnsLabel'
param skuName = '$skuName'
param skuTier = '$skuTier'
param ipVersion = '$ipVersion'
param allocationMethod = '$allocationMethod'
param idleTimeout = $idleTimeout
param zones = [
  '$zones'
]
param tags = $tags
"@
			
			if ($ddosPlanId)
			{
				$bicepTemplateContent += @"
param ddosProtectionPlanId string
param ddosProtectionMode string
"@
				$bicepParamsContent += @"
param ddosProtectionPlanId = '$ddosPlanId'
param ddosProtectionMode = '$ddosMode'
"@
			}
			if ($natGatewayId)
			{
				$bicepTemplateContent += @"
param natGatewayId string
"@
				$bicepParamsContent += @"
param natGatewayId = '$natGatewayId'
"@
			}
			
			$bicepTemplateContent += @"
resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: publicIpName
  location: resourceGroup().location
  properties: {
    publicIPAddressVersion: ipVersion
    publicIPAllocationMethod: allocationMethod
    dnsSettings: {
      domainNameLabel: domainNameLabel
    }
    idleTimeoutInMinutes: idleTimeout
"@
			
			if ($ddosPlanId)
			{
				$bicepTemplateContent += @"
    ddosSettings: {
      ddosProtectionPlan: {
        id: ddosProtectionPlanId
      }
      protectionMode: ddosProtectionMode
    }
"@
			}
			if ($natGatewayId)
			{
				$bicepTemplateContent += @"
    natGateway: {
      id: natGatewayId
    }
"@
			}
			
			$bicepTemplateContent += @"
  }
  sku: {
    name: skuName
    tier: skuTier
  }
  zones: zones
  tags: tags
}
"@
		}
	}
	else
	{
		$getAzResourceList = Get-AzResource
		
		$getAzResourceListTypeSorted = $getAzResourceList.resourcetype | Select-Object -Unique
		$getAzResourceListRgSorted = $getAzResourceList.resourceGroupName | Select-Object -Unique
		
		
		$bicepTemplateContent += @"
param resourceGroupName string
param location string
param tags object

resource rg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
}
"@
		#Template preperation
		foreach ($sortedResource in $getAzResourceListTypeSorted)
		{
			if ($sortedResource -eq 'Microsoft.Storage/storageAccounts')
			{
				
			}
			elseif ($sortedResource -eq 'Microsoft.KeyVault/vaults')
			{
				
			}
			elseif ($sortedResource -eq 'Microsoft.Compute/disks' -or $sortedResource -eq 'Microsoft.Compute/virtualMachines' -or $sortedResource -eq 'Microsoft.Compute/virtualMachines/extensions' -or $sortedResource -eq 'Microsoft.Network/networkInterfaces')
			{
				
			}
			elseif ($sortedResource -eq 'Microsoft.Network/networkSecurityGroups' -or $sortedResource -eq 'Microsoft.Network/virtualNetworks')
			{
				
			}
			elseif ($sortedResource -eq 'Microsoft.SqlVirtualMachine/SqlVirtualMachines')
			{
				
			}
			if ($sortedResource -eq 'Microsoft.Network/publicIPAddresses')
			{
				
			}
		}
		$bicepRgParamsContent = @()
		foreach ($rg in $getAzResourceListRgSorted)
		{
			#Starting with the base params for RG's
			$rgInfo = Get-AzResourceGroup -Name $rg
			$tags = if ($null -ne $rgInfo.Tags) { GenerateTagsBicepBlock -Tags $rgInfo.Tags }
			else { '{}' }
			$bicepRgParamsContent += @"
using '$ExportFileName.bicep'

param resourceGroupName = '$rg'

param location = '$($rgInfo.location)'

param object = '$tags'

"@
		}
		
		foreach ($resource in $getAzResourceList)
		{
			#continue here with the rest of the types for parameters
			if ($resource.resourcetype -like '*storageAccounts')
			{
				
			}
		}
	}
	# Define output paths
	$bicepTemplatePath = "./output/template_$($ExportFileName).bicep"
	$bicepParamsPath = "./output/$ExportFileName.bicepparam"
	#For rg's we need to split them
	foreach ($rg in $bicepRgParamsContent)
		{
			if ($rg -match "param resourceGroupName = '(.+?)'")
			{
				Write-Host "Now processing params"
				$rgParamsExportPath = "./output/$($Subscription)_$($Matches[1]).bicepparam"
				$rg | Out-File -FilePath $rgParamsExportPath -Encoding utf8
				Write-Output "Bicep RG Param file created: $rgParamsExportPath"
			}
		}
	# Write Bicep template and params content to files
	$bicepTemplateContent | Out-File -FilePath $bicepTemplatePath -Encoding utf8
	$bicepParamsContent | Out-File -FilePath $bicepParamsPath -Encoding utf8
	
	Write-Output "Bicep template file created: $bicepTemplatePath"
	Write-Output "Bicep parameter file created: $bicepParamsPath"
}
function GenerateTagsBicepBlock
{
	Param (
		[hashtable]$Tags
	)
	
	$tagsContent = "{"
	foreach ($key in $Tags.Keys)
	{
		$tagsContent += @"
  '$key': '$($Tags[$key])',
"@
	}
	$tagsContent += "}"
	return $tagsContent
}

# Export the function when the module is loaded
Export-ModuleMember -Function ExportTo-Bicep

<#
To do:
Build more components for:
Vnet's (and subnet)
Public IP (PIP)
Virtual Machines
Other compute resources (SQL/EKS/AKS)
Storage accounts 
Firewall
Network and internal load balancers
Application gateway (with WAF)
Nat gateway
Keyvault

Local network gateway
Virtual network gateway (connections will added later)
Expressroute circuits

Also add a conversion tool that uses azurerm to convert to terraform.
Similar to aztfexport

Limitations:
Cannot extract secrets like service provider keys in terms of express route

#>
