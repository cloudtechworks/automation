using './expressRouteConnection.bicep' // Reference to path containing the resource definition

param expressRouteConnectionName = 'myconnection' //The name of the ExpressRoute Connection

param location = 'westeurope' //The location for the resource

param virtualNetworkGatewayId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/replacemerg/providers/Microsoft.Network/virtualNetworkGateways/replacementgateway' //replace the subscription, rg and gateway

param expressRouteCircuitId = '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/replacemerg/providers/Microsoft.Network/expressRouteCircuits/replacemecircuit' //replace the subscription, rg and circuit

param connectionRoutingWeight = 0 //The routing weight for the ExpressRoute Connection.

param authorizationName = 'auth-key-on-circuit' //Optional as parameter IF the circuit is in the same subscription with the virtual network gateway. Elsewise it's mandatory
