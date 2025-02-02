@description('The name of the ExpressRoute Connection')
param expressRouteConnectionName string

@description('The ID of the Virtual Network Gateway to connect to')
param virtualNetworkGatewayId string

@description('The ID of the ExpressRoute Circuit')
param expressRouteCircuitId string

@description('The routing weight for the ExpressRoute Connection')
@minValue(0)
@maxValue(32000)
param connectionRoutingWeight int

@description('The authorization key for the ExpressRoute Connection')
param authorizationName string = '' //optional in parameters

@description('The location for the resource')
param location string = resourceGroup().location

@description('Required tags')
param tags object = {
  MyKey: 'Value'
}

resource expressRouteConnection 'Microsoft.Network/connections@2024-01-01' = {
  name: expressRouteConnectionName
  location: location
  tags: tags
  properties: {
    virtualNetworkGateway1: {
      properties: {}
      id: virtualNetworkGatewayId
    }
    connectionType: 'ExpressRoute'
    routingWeight: connectionRoutingWeight
    enableBgp: false
    usePolicyBasedTrafficSelectors: false
    ipsecPolicies: []
    trafficSelectorPolicies: []
    authorizationKey: first(filter(expressRouteCircuit.properties.authorizations, a => a.name == authorizationName))!.properties.authorizationKey
    peer: {
      id: expressRouteCircuitId
    }
    expressRouteGatewayBypass: false
  }
}

resource expressRouteCircuit 'Microsoft.Network/expressRouteCircuits@2024-01-01' existing = {
  name: last(split(expressRouteCircuitId, '/'))
  scope: resourceGroup(split(expressRouteCircuitId, '/')[2], split(expressRouteCircuitId, '/')[4])
}
