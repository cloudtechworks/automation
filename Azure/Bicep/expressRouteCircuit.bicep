param expressRouteCircuit object
param peering object
param location string = resourceGroup().location

@secure()
param sharedkey string

param authKeyNames array

@description('Required tags')
param tags object = {
  MyKey: 'Value'
}

resource expressRouteCircuit_name 'Microsoft.Network/expressRouteCircuits@2024-01-01' = {
  name: expressRouteCircuit.name
  location: location
  tags: tags
  sku: {
    name: '${expressRouteCircuit.tier}_${expressRouteCircuit.family}'
    tier: expressRouteCircuit.tier
    family: expressRouteCircuit.family
  }
  properties: {
    allowClassicOperations: false
    serviceProviderProperties: {
      serviceProviderName: expressRouteCircuit.serviceProviderName
      peeringLocation: expressRouteCircuit.peeringLocation
      bandwidthInMbps: expressRouteCircuit.bandwidthInMbps
    }
    authorizations: authKeyNames
    peerings: [
      {
        name: 'AzurePrivatePeering'
        properties: {
          peeringType: 'AzurePrivatePeering'
          peerASN: peering.peerASN
          primaryPeerAddressPrefix: peering.primaryPeerAddressPrefix
          secondaryPeerAddressPrefix: peering.secondaryPeerAddressPrefix
          vlanId: peering.vlanId
          sharedKey: sharedkey
        }
      }
    ]
  }
}
