using '../../../../Generic-templates/networking/virtual-network-gateways/v2.0/templates/virtual-network-gateways.bicep'

param virtualNetworkName = 'My-Virtual-Network' // Name of the virtual network

param gatewayName = 'My-Virtual-Network-Gateway' // Name of the gateway

param gatewayPublicIPName1 = 'My-Virtual-Network-Gateway-IP1' // Public IP name for the gateway

param gatewaySku = 'ErGw2AZ' // ErGw1AZ, ErGw2AZ, ErGw3AZ, VpnGw1, VpnGw2, VpnGw3, VpnGw4, VpnGw5, VpnGw6

// If you pick ExpressRoute, you need to also provide the circuit type. For vpn, you can ignore this parameter.
param gatewayType = 'ExpressRoute'
param circuitType = 'Classic'
