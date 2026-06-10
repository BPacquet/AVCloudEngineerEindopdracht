// modules/network/spoke-vnet.bicep
// Spoke VNet — Contoso-Prod Subscription
// Subnetten conform opdracht: appgw | web | func | data | sqli | mgmt
// cidrSubnet() gebruikt voor dynamische CIDR-berekening vanuit addressPrefix

@description('Azure region')
param location string

@description('VNet name')
param vnetName string

@description('VNet address prefix — standaard 10.20.0.0/16')
param addressPrefix string

@description('Tags')
param tags object

// ── Subnet definities ─────────────────────────────────────────────
// cidrSubnet(prefix, newBits, index) berekent het subnet CIDR dynamisch.
// Gebruik van hardcoded CIDRs vermijden zodat de module herbruikbaar is
// voor zowel prd (10.20.0.0/16) als dev (10.30.0.0/16).
//
// Dimensionering conform opdracht:
//   /27 = 32 IPs, 27 bruikbaar  → appgw, func, mgmt
//   /24 = 256 IPs, 251 bruikbaar → web, data, sqli (groeimarge)
var subnets = [
  {
    // snet-spoke-appgw: Application Gateway WAF v2
    // /27: max 10 CU-instanties = 11 IPs actief — /27 (27 bruikbaar) voldoende
    name:          'snet-spoke-appgw'
    addressPrefix: cidrSubnet(addressPrefix, 27, 0)   // 10.20.0.0/27
    delegations:   []
  }
  {
    // snet-spoke-web: App Service VNet Integration (delegatie vereist)
    // /24: 2 Plans × auto-scale max 6 inst = 12 IPs actief — groeimarge
    name:          'snet-spoke-web'
    addressPrefix: cidrSubnet(addressPrefix, 24, 1)   // 10.20.1.0/24
    delegations: [
      {
        name: 'delegation-appservice'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
  {
    // snet-spoke-func: Azure Functions VNet Integration
    // /27: Microsoft minimum vereiste voor VNet Integration
    name:          'snet-spoke-func'
    addressPrefix: cidrSubnet(addressPrefix, 27, 8)   // 10.20.2.0/27
    delegations: [
      {
        name: 'delegation-functions'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
  {
    // snet-spoke-data: Private Endpoints only (SQL MI, KV, Blob, SB, App)
    // /24: 5 PEs actief (elk 1 IP) — groeimarge voor toekomstige PaaS
    name:          'snet-spoke-data'
    addressPrefix: cidrSubnet(addressPrefix, 24, 3)   // 10.20.3.0/24
    delegations:   []
  }
  {
    // snet-sqli-dedicated: SQL Managed Instance — DEDICATED subnet
    // /24 verplicht door Azure — geen andere resources toegestaan!
    // Delegatie: Microsoft.Sql/managedInstances
    name:          'snet-sqli-dedicated'
    addressPrefix: cidrSubnet(addressPrefix, 24, 4)   // 10.20.4.0/24
    delegations: [
      {
        name: 'delegation-sqlmi'
        properties: {
          serviceName: 'Microsoft.Sql/managedInstances'
        }
      }
    ]
  }
  {
    // snet-spoke-mgmt: DevOps agents en Jump VMs
    // /27: 5-10 VMs verwacht — 27 bruikbare IPs voldoende
    name:          'snet-spoke-mgmt'
    addressPrefix: cidrSubnet(addressPrefix, 27, 20)  // 10.20.5.0/27
    delegations:   []
  }
]

// ── NSG: nsg-web ─────────────────────────────────────────────────
// Conform nsg-regels.xlsx en README-nsg.md
// Inbound: alleen AGW-subnet → web op :443
// Outbound: web → data-subnet op SQL/KV/SB poorten
resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name:     'nsg-web'
  location: location
  tags:     tags
  properties: {
    securityRules: [
      {
        name: 'Allow-AppGW-Inbound'
        properties: {
          priority:                 100
          protocol:                 'Tcp'
          access:                   'Allow'
          direction:                'Inbound'
          sourceAddressPrefix:      cidrSubnet(addressPrefix, 27, 0)  // snet-spoke-appgw
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '443'
          description:              'AGW stuurt HTTPS requests naar App Service'
        }
      }
      {
        name: 'Allow-Bastion-RDP-SSH'
        properties: {
          priority:                 120
          protocol:                 'Tcp'
          access:                   'Allow'
          direction:                'Inbound'
          sourceAddressPrefix:      'AzureBastionSubnet'
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '22'
          description:              'Azure Bastion beheertoegang'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority:                 4096
          protocol:                 '*'
          access:                   'Deny'
          direction:                'Inbound'
          sourceAddressPrefix:      '*'
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '*'
          description:              'Default deny inbound'
        }
      }
      {
        name: 'Allow-Web-to-SQL'
        properties: {
          priority:                 100
          protocol:                 'Tcp'
          access:                   'Allow'
          direction:                'Outbound'
          sourceAddressPrefix:      '*'
          sourcePortRange:          '*'
          destinationAddressPrefix: cidrSubnet(addressPrefix, 24, 3)  // snet-spoke-data
          destinationPortRange:     '1433'
          description:              'App Service naar SQL MI via Private Endpoint'
        }
      }
      {
        name: 'Allow-Web-to-KV-Storage-SB'
        properties: {
          priority:                 110
          protocol:                 'Tcp'
          access:                   'Allow'
          direction:                'Outbound'
          sourceAddressPrefix:      '*'
          sourcePortRange:          '*'
          destinationAddressPrefix: cidrSubnet(addressPrefix, 24, 3)  // snet-spoke-data
          destinationPortRange:     '443'
          description:              'App Service naar KV, Blob en App Service PE'
        }
      }
      {
        name: 'Allow-Web-to-AzureAD'
        properties: {
          priority:                 160
          protocol:                 'Tcp'
          access:                   'Allow'
          direction:                'Outbound'
          sourceAddressPrefix:      '*'
          sourcePortRange:          '*'
          destinationAddressPrefix: 'AzureActiveDirectory'
          destinationPortRange:     '443'
          description:              'Managed Identity token aanvragen via Entra ID'
        }
      }
      {
        name: 'Deny-All-Outbound'
        properties: {
          priority:                 4096
          protocol:                 '*'
          access:                   'Deny'
          direction:                'Outbound'
          sourceAddressPrefix:      '*'
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '*'
          description:              'Default deny outbound — overig via Hub Firewall (UDR)'
        }
      }
    ]
  }
}

// ── NSG: nsg-data (Private Endpoint subnet) ───────────────────────
resource nsgData 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name:     'nsg-data'
  location: location
  tags:     tags
  properties: {
    securityRules: [
      {
        name: 'Allow-Web-to-SQL-PE'
        properties: {
          priority:                 100
          protocol:                 'Tcp'
          access:                   'Allow'
          direction:                'Inbound'
          sourceAddressPrefix:      cidrSubnet(addressPrefix, 24, 1)  // snet-spoke-web
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '1433'
          description:              'App Service naar SQL MI via PE'
        }
      }
      {
        name: 'Allow-Web-Func-to-KV-PE'
        properties: {
          priority:                 110
          protocol:                 'Tcp'
          access:                   'Allow'
          direction:                'Inbound'
          sourceAddressPrefix:      cidrSubnet(addressPrefix, 24, 1)  // snet-spoke-web
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '443'
          description:              'App Service en Functions naar KV en Blob PE'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority:                 4096
          protocol:                 '*'
          access:                   'Deny'
          direction:                'Inbound'
          sourceAddressPrefix:      '*'
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '*'
          description:              'Default deny — PE-subnet enkel via expliciete regels'
        }
      }
    ]
  }
}

// ── Virtual Network ───────────────────────────────────────────────
resource spokeVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
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
        delegations:   subnet.delegations

        // NSG koppelen aan web en data subnet
        networkSecurityGroup: subnet.name == 'snet-spoke-web' ? {
          id: nsgWeb.id
        } : subnet.name == 'snet-spoke-data' ? {
          id: nsgData.id
        } : null

        // Private Endpoint policies uitschakelen op data-subnet
        privateEndpointNetworkPolicies: subnet.name == 'snet-spoke-data'
          ? 'Disabled'
          : 'Enabled'
      }
    }]
  }
}

// ── Outputs ───────────────────────────────────────────────────────
output vnetId       string = spokeVnet.id
output vnetName     string = spokeVnet.name
output appgwSubnetId string = spokeVnet.properties.subnets[0].id
output webSubnetId   string = spokeVnet.properties.subnets[1].id
output funcSubnetId  string = spokeVnet.properties.subnets[2].id
output dataSubnetId  string = spokeVnet.properties.subnets[3].id
output sqlSubnetId   string = spokeVnet.properties.subnets[4].id
output mgmtSubnetId  string = spokeVnet.properties.subnets[5].id
