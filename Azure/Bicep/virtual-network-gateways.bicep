// Parameters
param tags object = {}
@allowed([
  'RouteBased'
  'PolicyBased'
])
param vpnType string = 'RouteBased'
param virtualNetworkName string
param gatewayPublicIPName1 string
param gatewayName string
param gatewaySku string = 'VpnGw1AZ'
@allowed([
  'Vpn'
  'ExpressRoute'
])
param gatewayType string = 'Vpn'
@allowed([
  'Unspecified' // Default value, used automatically for gatewayType VPN
  'Classic' // Used for ER Circuits 1, 2, 3 and 4
  'Germany' // Used for ER Circuits 5, 6, 7 and 8
])
param circuitType string = 'Unspecified'
param vnetGatewayConfigName string = 'vnetGatewayConfig1'
param location string = resourceGroup().location
param workspace object = {
  name: 'replacemeworkspace' // Replace with your workspace name
  subscription: '00000000-0000-0000-0000-000000000000' // Replace with your subscription ID
  resourceGroup: 'replacemerg' // Replace with your workspace resource group
}
param diagName string = 'vnetgateway'
param publicIPZones array = [
  '1'
  '2'
  '3'
]
param publicIPAllocationMethod string = 'Static'
param publicIPAddressesSKUName string = 'Standard'

// Variables
var commonTags = { MyTag: 'MyValue' } // Replace with your DEFAULT TAG
var gatewaySubnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets/', virtualNetworkName, 'GatewaySubnet')
var expressRouteCircuits = {
  Classic: {
    expressRouteCircuitsIds: [
      '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/replacemerg/providers/Microsoft.Network/expressRouteCircuits/replacemecircuit'
      '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/replacemerg/providers/Microsoft.Network/expressRouteCircuits/replacemecircuit'
      '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/replacemerg/providers/Microsoft.Network/expressRouteCircuits/replacemecircuit'
      '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/replacemerg/providers/Microsoft.Network/expressRouteCircuits/replacemecircuit'
    ]
    weight: substring(gatewayName, 2, 2) == '20' ? [100, 25, 50, 0] : [50, 0, 100, 25]
    suffix: ['Primary1', 'Secondary1', 'Primary2', 'Secondary2']
  }
  Germany: {
    expressRouteCircuitsIds: [
      '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/replacemerg/providers/Microsoft.Network/expressRouteCircuits/replacemecircuit'
      '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/replacemerg/providers/Microsoft.Network/expressRouteCircuits/replacemecircuit'
      '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/replacemerg/providers/Microsoft.Network/expressRouteCircuits/replacemecircuit'
      '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/replacemerg/providers/Microsoft.Network/expressRouteCircuits/replacemecircuit'
    ]
    weight: [100, 25, 50, 0]
    suffix: ['Primary1', 'Secondary1', 'Primary2', 'Secondary2']
  }
  Unspecified: {
    expressRouteCircuitsIds: []
    weight: []
    suffix: []
  }
}
var expressRouteCircuitsIds = expressRouteCircuits[circuitType].expressRouteCircuitsIds
var expressRouteConnectionWeights = expressRouteCircuits[circuitType].weight
var expressRouteConnectionSuffixes = expressRouteCircuits[circuitType].suffix

output circuitTypeError string = (gatewayType == 'ExpressRoute' && circuitType == 'Unspecified')
  ? 'The circuitType parameter must be set when the gatewayType is ExpressRoute'
  : 'All parameters are valid.'

resource expressRouteCircuitsForAuths 'Microsoft.Network/expressRouteCircuits@2024-01-01' existing = [
  for (erc, i) in expressRouteCircuitsIds: {
    name: last(split(expressRouteCircuitsIds[i], '/'))
    scope: resourceGroup(split(expressRouteCircuitsIds[i], '/')[2], split(expressRouteCircuitsIds[i], '/')[4])
  }
]

resource expressRouteConnection 'Microsoft.Network/connections@2024-01-01' = [
  for (erc, i) in expressRouteCircuitsIds: {
    name: 'EXPCON${substring(gatewayName, 2, length(gatewayName)-2)}-${expressRouteConnectionSuffixes[i]}'
    location: location
    tags: union(tags, commonTags)
    properties: {
      virtualNetworkGateway1: {
        properties: {}
        id: virtualNetworkGateways.id
      }
      connectionType: 'ExpressRoute'
      routingWeight: expressRouteConnectionWeights[i]
      enableBgp: false
      usePolicyBasedTrafficSelectors: false
      ipsecPolicies: []
      trafficSelectorPolicies: []
      authorizationKey: empty(filter(
          expressRouteCircuitsForAuths[i].properties.authorizations,
          a => a.name == 'AUTH-${last(split(erc,'/'))}-${gatewayName}'
        ))
        ? null
        : filter(
            expressRouteCircuitsForAuths[i].properties.authorizations,
            a => a.name == 'AUTH-${last(split(erc,'/'))}-${gatewayName}'
          )[0].properties.authorizationKey
      peer: {
        id: expressRouteCircuitsIds[i]
      }
      expressRouteGatewayBypass: false
    }
  }
]

resource publicIPAddresses 'Microsoft.Network/publicIPAddresses@2023-02-01' = {
  name: gatewayPublicIPName1
  location: location
  tags: union(tags, commonTags)
  sku: {
    name: publicIPAddressesSKUName
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
  }
  zones: publicIPZones
}

resource virtualNetworkGateways 'Microsoft.Network/virtualNetworkGateways@2023-02-01' = {
  name: gatewayName
  location: location
  tags: union(tags, commonTags)
  properties: {
    ipConfigurations: [
      {
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: gatewaySubnetRef
          }
          publicIPAddress: {
            id: publicIPAddresses.id
          }
        }
        name: vnetGatewayConfigName
      }
    ]
    sku: {
      name: gatewaySku
      tier: gatewaySku
    }
    gatewayType: gatewayType
    vpnType: vpnType
    enableBgp: false
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: diagName
  scope: virtualNetworkGateways
  properties: {
    workspaceId: resourceId(
      workspace.subscription,
      workspace.resourceGroup,
      'microsoft.operationalinsights/workspaces/',
      workspace.name
    )
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: true
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: true
          days: 0
        }
      }
    ]
  }
}
