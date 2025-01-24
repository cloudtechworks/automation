# Naming convention check will be called to align new resources with a set naming convention
$pathToNamingConventionServices = ".\Azure\namingConventionService.ps1"


$rgBaseName = Read-Host -Prompt "What is the FULL NAME of the RG you would like to target? (will be created based on the 'base' name if it is non-existing)"
$rg = Get-AzResourceGroup -Name $rgBaseName -ErrorAction SilentlyContinue
if (-not $rg){
    $location = Read-Host -Prompt "What is the location you want the RG to be located in? type eastus, westeurope or similar" # see the full list here https://azuretracks.com/2021/04/current-azure-region-names-reference/
    $instanceNumber = Read-Host -Prompt "What is the base RG number (e.g. 1, 100, 001 etc) you would like to create?"
    $newRgName = . $pathToNamingConventionServices -region $location -resourceType "resourcegroup" -resourceBaseName $rgBaseName -instanceNumber $instanceNumber
    New-AzResourceGroup -Name $newRgName -Location $location
}

$vnetBaseName = Read-Host -Prompt "What is the FULL NAME of the VNET you would like to target? (will be created on the 'base' name if it is non-existing)"
$vnet = Get-AzResourceGroup -Name $vnetBaseName -ErrorAction SilentlyContinue
if (-not $vnet) {
    $location = Read-Host -Prompt "What is the location you want the VNET to be located in? type eastus, westeurope or similar" # see the full list here https://azuretracks.com/2021/04/current-azure-region-names-reference/
    $instanceNumber = Read-Host -Prompt "What is the base VNET number (e.g. 1, 100, 001 etc) you would like to create?"
    $vnetAddressPrefix = Read-Host -Prompt "What address space would you like to assign to the VNET? e.g."
    $newVnetName = . $pathToNamingConventionServices -region $location -resourceType "virtualnetwork" -resourceBaseName $vnetBaseName -instanceNumber $instanceNumber
    New-AzVirtualNetwork -ResourceGroupName $rgName -Location $location -Name $newVnetName -AddressPrefix $vnetAddressPrefix
}
else{
    $addAddressSpaces = Read-Host -Prompt "Would you like to add an additional address space to the VNET? (y/n)"
    if($addAddressSpaces -eq "y"){
        $addressSpace = Read-Host -Prompt "What (sub) address space would you like to add to the VNET? e.g. 10.1.0.0/16"
        $vnet.AddressSpace.AddressPrefixes.Add($addressSpace)
        Set-AzVirtualNetwork -VirtualNetwork $vnet
    }
}

$needSubnet = Read-Host -Prompt "Would you like to create a Subnet? (y/n)"
if($needSubnet -eq "y"){
    $subnetCount = Read-Host -Prompt "How many subnets would you like to create?"
    for ($i = 1; $i -le $subnetCount; $i++) {
        $subnetBaseName = Read-Host -Prompt "What is the 'base' name of subnet number: $number you would like to target? (will be created by 'base' name if it is non-existing)"
        if (-not $rg){
            Write-Host "The VNET now includes the following address spaces" $vnet.$addressSpace.AddressPrefixes
            $subnetAddressPrefix = Read-Host "What (sub) address space would you like to assign to the subnet? e.g. 10.0.1.0/24"
            $location = Read-Host -Prompt "What is the location you want the Subnet to be located in? type eastus, westeurope or similar" # see the full list here https://azuretracks.com/2021/04/current-azure-region-names-reference/
            $instanceNumber = Read-Host -Prompt "What is the base Subnet number (e.g. 1, 100, 001 etc) you would like to create?"
            $newSubnetName = . $pathToNamingConventionServices -region $location -resourceType "subnet" -resourceBaseName $subnetBaseName -instanceNumber $instanceNumber
            Add-AzVirtualNetworkSubnetConfig -Name $newSubnetName -AddressPrefix $subnetAddressPrefix -VirtualNetwork $vnet
        }
    }
}

$publicIpBaseName = Read-Host -Prompt "Enter the base name for the Public IP"
$publicIp = Get-AzPublicIpAddress -ResourceGroupName $rgName -Name $publicIpBaseName -ErrorAction SilentlyContinue

if (-not $publicIp) {
    $location = $vnet.Location
    $instanceNumber = Read-Host -Prompt "Enter the base Public IP number (e.g. 1, 100, 001 etc)"
    $newPublicIpName = GenerateResourceName -region $location -resourceType "publicip" -resourceBaseName $publicIpBaseName -instanceNumber $instanceNumber

    Write-Output "Creating Public IP '$newPublicIpName'..."
    $publicIp = New-AzPublicIpAddress -Name $newPublicIpName -ResourceGroupName $rgName -Location $location -AllocationMethod Static -Sku Standard
    Write-Output "Public IP '$newPublicIpName' created successfully."
} else {
    Write-Output "Using existing Public IP '$publicIpBaseName'."
}

$firewallBaseName = Read-Host -Prompt "Enter the base name for the Firewall"
$firewall = Get-AzFirewall -ResourceGroupName $rgName -Name $firewallBaseName -ErrorAction SilentlyContinue
if (-not $firewall) {
    $location = $publicIp.Location
    $instanceNumber = Read-Host -Prompt "Enter the base Firewall number (e.g. 1, 100, 001 etc)"
    $newFirewallName = GenerateResourceName -region $location -resourceType "firewall" -resourceBaseName $firewallBaseName -instanceNumber $instanceNumber

    Write-Output "Creating Firewall '$newFirewallName'..."
    $firewall = New-AzFirewall -Name $newFirewallName -ResourceGroupName $rgName -Location $location -VirtualNetwork $vnet -PublicIpAddress $publicIp
    Write-Output "Firewall '$newFirewallName' created successfully."
} else {
    Write-Output "Using existing Firewall '$firewallBaseName'."
}

#Save the firewall private IP address for future use
$firewallPrivateIP = $firewall.IpConfigurations.privateipaddress

$appRuleCollections = Get-Content -Path .\applicationCollections.json | ConvertFrom-Json

foreach ($appCollection in $appRuleCollections) {
    # Check if the application rule collection already exists
    $existingAppRuleCollection = $firewall.ApplicationRuleCollections | Where-Object { $_.Name -eq $appCollection.Name }
    
    if ($null -eq $existingAppRuleCollection) {
        # If it doesn't exist, create a new application rule collection
        Write-Output "Creating new Application Rule Collection: $($appCollection.Name)"
        
        $rules = @()
        foreach ($rule in $appCollection.Rules) {
            $rules += New-AzFirewallApplicationRule -Name $rule.Name -SourceAddress $rule.SourceAddress -Protocol $rule.Protocol -TargetFqdn $rule.TargetFqdn
        }
        
        New-AzFirewallApplicationRuleCollection -AzureFirewall $firewall -Name $appCollection.Name -Priority $appCollection.Priority -ActionType $appCollection.ActionType -Rule $rules
    } else {
        Write-Output "Application Rule Collection '$($appCollection.Name)' already exists. Checking for existing rules."

        # Check and create only missing rules
        foreach ($rule in $appCollection.Rules) {
            $existingRule = $existingAppRuleCollection.Rules | Where-Object { $_.Name -eq $rule.Name }

            if ($null -eq $existingRule) {
                Write-Output "Adding new rule '$($rule.Name)' to existing collection '$($appCollection.Name)'."
                $newRule = New-AzFirewallApplicationRule -Name $rule.Name -SourceAddress $rule.SourceAddress -Protocol $rule.Protocol -TargetFqdn $rule.TargetFqdn
                $existingAppRuleCollection.Rules += $newRule
                
                # Note: Real code should have a call to update the collection with this new rule, this snippet assumes
                # manipulation of the object in memory before pushing updates, revise according to real APIs.
            } else {
                Write-Output "Rule '$($rule.Name)' already exists within the collection '$($appCollection.Name)'."
            }
        }
        
        # Update the existing firewall collection
        Set-AzFirewall -AzureFirewall $firewall
    }
}

# Process network rule
$netRuleCollections = Get-Content -Path .\networkCollections.json | ConvertFrom-Json
foreach ($netCollection in $netRuleCollections) {
    # Check if the network rule collection already exists
    $existingNetRuleCollection = $firewall.NetworkRuleCollections | Where-Object { $_.Name -eq $netCollection.Name }
    
    if ($null -eq $existingNetRuleCollection) {
        # If it doesn't exist, create a new network rule collection
        Write-Output "Creating new Network Rule Collection: $($netCollection.Name)"
        
        $rules = @()
        foreach ($rule in $netCollection.Rules) {
            $rules += New-AzFirewallNetworkRule -Name $rule.Name -SourceAddress $rule.SourceAddress -DestinationAddress $rule.DestinationAddress -DestinationPort $rule.DestinationPort -Protocol $rule.Protocol
        }
        
        New-AzFirewallNetworkRuleCollection -AzureFirewall $firewall -Name $netCollection.Name -Priority $netCollection.Priority -ActionType $netCollection.ActionType -Rule $rules
    } else {
        Write-Output "Network Rule Collection '$($netCollection.Name)' already exists. Checking for existing rules."

        # Check and create only missing rules
        foreach ($rule in $netCollection.Rules) {
            $existingRule = $existingNetRuleCollection.Rules | Where-Object { $_.Name -eq $rule.Name }

            if ($null -eq $existingRule) {
                Write-Output "Adding new rule '$($rule.Name)' to existing collection '$($netCollection.Name)'."
                $newRule = New-AzFirewallNetworkRule -Name $rule.Name -SourceAddress $rule.SourceAddress -DestinationAddress $rule.DestinationAddress -DestinationPort $rule.DestinationPort -Protocol $rule.Protocol
                $existingNetRuleCollection.Rules += $newRule
                
                # Update the existing firewall collection
                Set-AzFirewall -AzureFirewall $firewall
            } else {
                Write-Output "Rule '$($rule.Name)' already exists within the collection '$($netCollection.Name)'."
            }
        }
    }
}

# Write several outputs
Write-Output "The firewall private IP address is: $firewallPrivateIP"