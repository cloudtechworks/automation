@description('Name of the Managed Identity')
param managedIdentity string

resource managedIdentity_resource 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = { //Use most recent api version
  name: managedIdentity
  location: resourceGroup().location // automatically use the resource group location
}
