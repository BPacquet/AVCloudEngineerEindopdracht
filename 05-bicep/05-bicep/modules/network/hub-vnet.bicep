param location string
param vnetName string
param addressPrefix string
param tags object

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [addressPrefix] }
    subnets: [
      {
        name: 'AzureFirewallSubnet'
        properties: { addressPrefix: cidrSubnet(addressPrefix, 26, 0) }
      }
      {
        name: 'AzureFirewallManagementSubnet'
        properties: { addressPrefix: cidrSubnet(addressPrefix, 26, 1) }
      }
      {
        name: 'GatewaySubnet'
        properties: { addressPrefix: cidrSubnet(addressPrefix, 27, 4) }
      }
      {
        name: 'AzureBastionSubnet'
        properties: { addressPrefix: cidrSubnet(addressPrefix, 26, 3) }
      }
      {
        name: 'snet-dns-resolver'
        properties: { addressPrefix: cidrSubnet(addressPrefix, 28, 16) }
      }
      {
        name: 'snet-shared-services'
        properties: { addressPrefix: cidrSubnet(addressPrefix, 24, 2) }
      }
    ]
  }
}

output vnetId string = hubVnet.id
output vnetName string = hubVnet.name
output firewallSubnetId string = hubVnet.properties.subnets[0].id
output gatewaySubnetId string = hubVnet.properties.subnets[2].id
output bastionSubnetId string = hubVnet.properties.subnets[3].id
