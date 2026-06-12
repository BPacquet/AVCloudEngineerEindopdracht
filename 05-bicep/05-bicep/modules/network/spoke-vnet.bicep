param location string
param vnetName string
param addressPrefix string
param tags object

resource nsgAppGw 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-appgw-${vnetName}'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '443'
          sourceAddressPrefix: 'Internet'
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-GatewayManager'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '65200-65535'
          sourceAddressPrefix: 'GatewayManager'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-web-${vnetName}'
  location: location
  tags: tags
}

resource nsgData 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-data-${vnetName}'
  location: location
  tags: tags
}

resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [addressPrefix] }
    subnets: [
      {
        name: 'snet-spoke-appgw'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 0)
          networkSecurityGroup: { id: nsgAppGw.id }
        }
      }
      {
        name: 'snet-spoke-web'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 1)
          networkSecurityGroup: { id: nsgWeb.id }
          delegations: [
            {
              name: 'delegation-web-serverfarms'
              properties: { serviceName: 'Microsoft.Web/serverFarms' }
            }
          ]
        }
      }
      {
        name: 'snet-spoke-functions'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 2)
          networkSecurityGroup: { id: nsgWeb.id }
          delegations: [
            {
              name: 'delegation-func-serverfarms'
              properties: { serviceName: 'Microsoft.Web/serverFarms' }
            }
          ]
        }
      }
      {
        name: 'snet-spoke-data'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 3)
          privateEndpointNetworkPolicies: 'Disabled'
          networkSecurityGroup: { id: nsgData.id }
        }
      }
      {
        name: 'snet-spoke-sqlmi'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 24, 4)
          delegations: [
            {
              name: 'delegation-sqlmi'
              properties: { serviceName: 'Microsoft.Sql/managedInstances' }
            }
          ]
        }
      }
      {
        name: 'snet-spoke-mgmt'
        properties: { addressPrefix: cidrSubnet(addressPrefix, 24, 5) }
      }
    ]
  }
}

output vnetId string = spokeVnet.id
output appgwSubnetId string = spokeVnet.properties.subnets[0].id
output webSubnetId string = spokeVnet.properties.subnets[1].id
output funcSubnetId string = spokeVnet.properties.subnets[2].id
output dataSubnetId string = spokeVnet.properties.subnets[3].id
output sqlSubnetId string = spokeVnet.properties.subnets[4].id
output mgmtSubnetId string = spokeVnet.properties.subnets[5].id
