<#
    this is a generic script written for the sole purpose of enabling an automatic naming convention via Powershell / By code
    Please feel free to use this tweak this and customize it as you need
    You could reference this in another scriptwhen callingthe function to establish a certain name for instance:
    $newRgName = . $pathToNamingConventionServices -region $location -resourceType "resourcegroup" -resourceBaseName $rgBaseName -instanceNumber $instanceNumber
    Where in this specific casethe path to naming convention services is a straight link to this Powershell script.
#>

param(
    [string]$resourceType,
    [string]$region = "westeurope",
    [string]$resourceBaseName,
    [int]$instanceNumber = 1
)

function Get-RegionAbbreviation {
    param (
        [string]$region
    )

    $regionMap = @{
        "westeurope"     = "WEU";
        "northeurope"    = "NEU";
        "germanywestcentral" = "GWC";
        "eastus"         = "EUS";
        "eastus2"        = "EUS2";
        "westus"         = "WUS";
        "centralus"      = "CUS";
        "southeastasia"  = "SEA"
        # Add more regions as needed
    }

    return $regionMap.$region
}

function Get-ResourceTypeAbbreviation {
    param (
        [string]$resourceType
    )

    $resourceTypeMap = @{
        "resourcegroup"        = "RG";    # Resource Group
        "virtualmachine"       = "VM";    # Virtual Machine
        "virtualmachinescaleset"= "VMSS"; # Virtual Machine Scale Set
        "availabilityset"      = "AS";    # Availability Set
        "storageaccount"       = "SA";    # Storage Account
        "virtualnetwork"       = "VNET";  # Virtual Network
        "subnet"               = "SN";    # Subnet
        "networkinterface"     = "NIC";   # Network Interface
        "networksecuritygroup" = "NSG";   # Network Security Group
        "publicipaddress"      = "PIP";   # Public IP Address
        "loadbalancer"         = "LB";    # Load Balancer
        "applicationgateway"   = "AG";    # Application Gateway
        "vpnconnection"        = "VPNCON";   # VPN Connection
        "firewall"             = "FW";    # Firewall
        "keyvault"             = "KV";    # Key Vault
        "database"             = "DB";    # Database (generic)
        "sqldatabase"          = "SQLDB"; # SQL Database
        "sqlserver"            = "SQLSVR";# SQL Server
        "cosmosdb"             = "COSMOS";# Cosmos DB
        "appservice"           = "AS";    # App Service
        "appserviceplan"       = "ASP";   # App Service Plan
        "functionapp"          = "FA";    # Function App
        "containerregistry"    = "ACR";   # Azure Container Registry
        "kubernetescluster"    = "AKS";   # Azure Kubernetes Service
        "containerinstance"    = "ACI";   # Azure Container Instances
        "eventhub"             = "EH";    # Event Hub
        "servicebus"           = "SB";    # Service Bus
        "logicapp"             = "LA";    # Logic App
        "automationaccount"    = "AA";    # Automation Account
        "searchservice"        = "SS";    # Search Service
        "cosmoscontainer"      = "COSCON";# Cosmos DB Container
        "storagetable"         = "STBL";  # Storage Table
        "expressroutecircuit"  = "ERC";   # ExpressRoute Circuit
        "expressrouteconnection"= "ERCON"; # ExpressRoute Connection
        "virtualnetworkgateway" = "VNG";  # Virtual Network Gateway
        "localgateway"         = "LGW";   # Local Gateway
        "sendgrid"             = "SG";    # SendGrid
        # Add additional resources as needed
    }

    return $resourceTypeMap.$resourceType
}

function GenerateResourceName {
    param (
        [string]$resourceType,
        [string]$region,
        [string]$resourceBaseName,
        [int]$instanceNumber
    )

    $regionAbbr = Get-RegionAbbreviation -region $region
    if (-not $regionAbbr) {
        throw "Invalid or unsupported region: $region"
    }

    $resourceAbbr = Get-ResourceTypeAbbreviation -resourceType $resourceType
    if (-not $resourceAbbr) {
        throw "Invalid or unsupported resource type: $resourceType"
    }

    $resourceName = "$resourceAbbr$regionAbbr-$resourceBaseName-{0:D3}" -f $instanceNumber
    return $resourceName
}

GenerateResourceName -resourceType $resourceType -region $region -resourceBaseName $resourceBaseName -instanceNumber $instanceNumber