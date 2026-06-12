// modules/network/nsg.bicep
// NSG-regels conform architectuur — zes NSGs voor de Spoke-Prod subnetten
// Alle regels gebaseerd op nsg-regels.xlsx en README-nsg.md

param location        string
param webSubnetId     string
param dataSubnetId    string
param funcSubnetId    string
param appgwSubnetId   string
param mgmtSubnetId    string
param tags            object

// ── nsg-appgw ─────────────────────────────────────────────────────
resource nsgAppGw 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name:     'nsg-appgw'
  location: location
  tags:     tags
  properties: {
    securityRules: [
      {
        name: 'Allow-GatewayManager'
        properties: {
          priority:                 100
          direction:                'Inbound'
          access:                   'Allow'
          protocol:                 'Tcp'
          sourceAddressPrefix:      'GatewayManager'
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '65200-65535'
          description:              'Verplicht voor AGW health probing — Azure service tag'
        }
      }
      {
        name: 'Allow-AzureLoadBalancer'
        properties: {
          priority:                 110
          direction:                'Inbound'
          access:                   'Allow'
          protocol:                 'Tcp'
          sourceAddressPrefix:      'AzureLoadBalancer'
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '*'
          description:              'Azure interne load balancer health checks'
        }
      }
      {
        name: 'Allow-HTTPS-Inbound'
        properties: {
          priority:                 120
          direction:                'Inbound'
          access:                   'Allow'
          protocol:                 'Tcp'
          sourceAddressPrefix:      'Internet'
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '443'
          description:              'Extern HTTPS-verkeer naar AGW'
        }
      }
      {
        name: 'Allow-HTTP-Inbound'
        properties: {
          priority:                 130
          direction:                'Inbound'
          access:                   'Allow'
          protocol:                 'Tcp'
          sourceAddressPrefix:      'Internet'
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '80'
          description:              'HTTP redirect naar HTTPS via AGW'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority:                 4096
          direction:                'Inbound'
          access:                   'Deny'
          protocol:                 '*'
          sourceAddressPrefix:      '*'
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '*'
          description:              'Default deny inbound'
        }
      }
    ]
  }
}

// ── nsg-web ───────────────────────────────────────────────────────
resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name:     'nsg-web'
  location: location
  tags:     tags
  properties: {
    securityRules: [
      {
        name: 'Allow-AppGW-to-Web'
        properties: {
          priority:                 100
          direction:                'Inbound'
          access:                   'Allow'
          protocol:                 'Tcp'
          sourceAddressPrefix:      '10.20.0.0/27'
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
          direction:                'Inbound'
          access:                   'Allow'
          protocol:                 'Tcp'
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
          direction:                'Inbound'
          access:                   'Deny'
          protocol:                 '*'
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
          direction:                'Outbound'
          access:                   'Allow'
          protocol:                 'Tcp'
          sourceAddressPrefix:      '*'
          sourcePortRange:          '*'
          destinationAddressPrefix: '10.20.3.0/24'
          destinationPortRange:     '1433'
          description:              'App Service naar SQL MI via Private Endpoint'
        }
      }
      {
        name: 'Allow-Web-to-KV'
        properties: {
          priority:                 110
          direction:                'Outbound'
          access:                   'Allow'
          protocol:                 'Tcp'
          sourceAddressPrefix:      '*'
          sourcePortRange:          '*'
          destinationAddressPrefix: '10.20.3.0/24'
          destinationPortRange:     '443'
          description:              'App Service naar Key Vault via Private Endpoint'
        }
      }
      {
        name: 'Allow-Web-to-AzureAD'
        properties: {
          priority:                 160
          direction:                'Outbound'
          access:                   'Allow'
          protocol:                 'Tcp'
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
          direction:                'Outbound'
          access:                   'Deny'
          protocol:                 '*'
          sourceAddressPrefix:      '*'
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '*'
          description:              'Default deny outbound'
        }
      }
    ]
  }
}

// ── nsg-data (Private Endpoints subnet) ──────────────────────────
resource nsgData 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name:     'nsg-data'
  location: location
  tags:     tags
  properties: {
    securityRules: [
      {
        name: 'Allow-Web-to-SQL-PE'
        properties: {
          priority:                 100
          direction:                'Inbound'
          access:                   'Allow'
          protocol:                 'Tcp'
          sourceAddressPrefix:      '10.20.1.0/24'
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '1433'
          description:              'App Service naar SQL MI via PE 10.20.3.4'
        }
      }
      {
        name: 'Allow-Web-to-KV-PE'
        properties: {
          priority:                 120
          direction:                'Inbound'
          access:                   'Allow'
          protocol:                 'Tcp'
          sourceAddressPrefix:      '10.20.1.0/24'
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '443'
          description:              'App Service naar Key Vault via PE 10.20.3.6'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority:                 4096
          direction:                'Inbound'
          access:                   'Deny'
          protocol:                 '*'
          sourceAddressPrefix:      '*'
          sourcePortRange:          '*'
          destinationAddressPrefix: '*'
          destinationPortRange:     '*'
          description:              'Default deny — PE-subnet niet bereikbaar van buiten'
        }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────
output nsgAppGwId string = nsgAppGw.id
output nsgWebId   string = nsgWeb.id
output nsgDataId  string = nsgData.id
