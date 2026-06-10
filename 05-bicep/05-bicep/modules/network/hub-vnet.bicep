// modules/network/hub-vnet.bicep
// Hub VNet — Connectivity Subscription
// Subnetten: AzureFirewallSubnet | GatewaySubnet | AzureBastionSubnet | snet-hub-dns | snet-hub-mgmt

param location      string
param vnetName      string
param addressPrefix string
param tags          object

// ── Subnetten conform opdracht ────────────────────────────────────
var subnets = [
  {
    name: 'AzureFirewallSubnet'           // Vereiste exacte naam!
    addressPrefix: '10.0.0.0/26'
    // Geen NSG — niet ondersteund op Firewall subnet
  }
  {
    name: 'AzureFirewallManagementSubnet' // Vereiste exacte naam!
    addressPrefix: '10.0.0.64/26'
  }
  {
    name: 'GatewaySubnet'                 // Vereiste exacte naam!
    addressPrefix: '10.0.1.0/27'
  }
  {
    name: 'AzureBastionSubnet'            // Vereiste exacte naam!
    addressPrefix: '10.0.2.0/27'
  }
  {
    name: 'snet-hub-dns'
    addressPrefix: '10.0.3.0/28'
  }
  {
    name: 'snet-hub-mgmt'
    addressPrefix: '10.0.4.0/28'
  }
]

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name:     vnetName
  location: location
  tags:     tags
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
      }
    }]
  }
}

// ── Outputs ───────────────────────────────────────────────────────
output vnetId         string = hubVnet.id
output vnetName       string = hubVnet.name
output firewallSubnetId string = hubVnet.properties.subnets[0].id
output gatewaySubnetId  string = hubVnet.properties.subnets[2].id
output bastionSubnetId  string = hubVnet.properties.subnets[3].id
output dnsSubnetId      string = hubVnet.properties.subnets[4].id
