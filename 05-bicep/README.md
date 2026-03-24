# 05 — bicep infrastructure as code

> **Deliverable**: Modulaire Bicep templates voor de volledige Azure-infrastructuur  
> **Gewicht**: 10% van de totale eindopdrachtscore

---

## opdracht

Schrijf **Bicep IaC-templates** voor de Contoso-omgeving. De templates moeten modulair, herbruikbaar en deployment-klaar zijn.

---

## structuur & conventies

### naamgevingsconventie

Gebruik de [Azure CAF naamgevingsconventie](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/azure-best-practices/resource-naming):

| Resource Type | Formaat | Voorbeeld |
|---|---|---|
| Resource Group | `rg-<app>-<env>` | `rg-contoso-prd` |
| Virtual Network | `vnet-<location>-<env>` | `vnet-weu-hub-prd` |
| Subnet | `snet-<role>-<env>` | `snet-web-prd` |
| NSG | `nsg-<subnet>-<env>` | `nsg-web-prd` |
| App Service | `app-<name>-<env>` | `app-contoso-prd` |
| App Service Plan | `asp-<name>-<env>` | `asp-contoso-prd` |
| SQL Server | `sql-<name>-<env>` | `sql-contoso-prd` |
| SQL Database | `sqldb-<name>-<env>` | `sqldb-contoso-prd` |
| Key Vault | `kv-<name>-<env>` | `kv-contoso-prd` |
| Storage Account | `st<name><env>` (geen koppeltekens!) | `stcontosoprdfr1` |

### mappenstructuur

```
05-bicep/
├── README.md
├── main.bicep                    ← Orchestrator — roept modules aan
├── main.bicepparam               ← Parameters voor productie
├── main.dev.bicepparam           ← Parameters voor development
└── modules/
    ├── network/
    │   ├── hub-vnet.bicep
    │   ├── spoke-vnet.bicep
    │   ├── nsg.bicep
    │   └── private-endpoint.bicep
    ├── compute/
    │   ├── app-service-plan.bicep
    │   ├── app-service.bicep
    │   └── function-app.bicep
    ├── data/
    │   ├── sql-server.bicep
    │   ├── sql-database.bicep
    │   └── storage-account.bicep
    └── security/
        ├── key-vault.bicep
        └── managed-identity.bicep
```

---

## starter code: main.bicep

```bicep
// main.bicep — Contoso Manufacturing Azure Infrastructure
// delaware cloud practice

targetScope = 'subscription'

// ──────────────────────────────────────────────
// Parameters
// ──────────────────────────────────────────────

@description('Environment: dev, tst, prd')
@allowed(['dev', 'tst', 'prd'])
param environment string

@description('Primary Azure region')
param location string = 'westeurope'

@description('Short location code for naming')
param locationCode string = 'weu'

@description('Application name')
param appName string = 'contoso'

@description('Tags to apply to all resources')
param tags object = {
  Environment: environment
  Application: appName
  Owner: 'team-cloud@contoso.be'
  CostCenter: 'CC-IT-001'
  DataClassification: 'internal'
  ManagedBy: 'bicep'
}

// ──────────────────────────────────────────────
// Variables
// ──────────────────────────────────────────────

var prefix = '${appName}-${environment}'
var hubVnetAddressPrefix = '10.0.0.0/16'
var spokeVnetAddressPrefix = '10.20.0.0/16'

// ──────────────────────────────────────────────
// Resource Groups
// ──────────────────────────────────────────────

resource rgNetworking 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-${prefix}-networking'
  location: location
  tags: tags
}

resource rgFrontend 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-${prefix}-frontend'
  location: location
  tags: tags
}

resource rgData 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-${prefix}-data'
  location: location
  tags: tags
}

resource rgSecurity 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-${prefix}-security'
  location: location
  tags: tags
}

resource rgMonitoring 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: 'rg-${prefix}-monitoring'
  location: location
  tags: tags
}

// ──────────────────────────────────────────────
// Modules
// ──────────────────────────────────────────────

module spokeVnet 'modules/network/spoke-vnet.bicep' = {
  name: 'deploy-spoke-vnet'
  scope: rgNetworking
  params: {
    location: location
    vnetName: 'vnet-${locationCode}-spoke-${environment}'
    addressPrefix: spokeVnetAddressPrefix
    tags: tags
  }
}

module keyVault 'modules/security/key-vault.bicep' = {
  name: 'deploy-key-vault'
  scope: rgSecurity
  params: {
    location: location
    keyVaultName: 'kv-${appName}-${environment}'
    tags: tags
  }
}

module appServicePlan 'modules/compute/app-service-plan.bicep' = {
  name: 'deploy-app-service-plan'
  scope: rgFrontend
  params: {
    location: location
    planName: 'asp-${prefix}'
    sku: environment == 'prd' ? 'P2v3' : 'B2'
    tags: tags
  }
}

module webApp 'modules/compute/app-service.bicep' = {
  name: 'deploy-web-app'
  scope: rgFrontend
  params: {
    location: location
    appName: 'app-${prefix}-web'
    appServicePlanId: appServicePlan.outputs.planId
    keyVaultName: keyVault.outputs.keyVaultName
    vnetSubnetId: spokeVnet.outputs.webSubnetId
    tags: tags
  }
}

module sqlServer 'modules/data/sql-server.bicep' = {
  name: 'deploy-sql-server'
  scope: rgData
  params: {
    location: location
    serverName: 'sql-${prefix}'
    tags: tags
  }
}

module sqlDatabase 'modules/data/sql-database.bicep' = {
  name: 'deploy-sql-database'
  scope: rgData
  params: {
    location: location
    serverName: sqlServer.outputs.serverName
    databaseName: 'sqldb-${prefix}'
    sku: environment == 'prd' ? 'BC_Gen5_4' : 'GP_Gen5_2'
    tags: tags
  }
}

// ──────────────────────────────────────────────
// Outputs
// ──────────────────────────────────────────────

output webAppName string = webApp.outputs.appName
output sqlServerFqdn string = sqlServer.outputs.fqdn
output keyVaultUri string = keyVault.outputs.keyVaultUri
```

---

## starter code: modules/network/spoke-vnet.bicep

```bicep
// modules/network/spoke-vnet.bicep

@description('Azure region')
param location string

@description('VNet name')
param vnetName string

@description('VNet address prefix')
param addressPrefix string

@description('Tags')
param tags object

// ── Subnets ──────────────────────────────────────────────────────────

var subnets = [
  {
    name: 'snet-appgw'
    addressPrefix: cidrSubnet(addressPrefix, 24, 0)  // Eerste /24
    delegations: []
  }
  {
    name: 'snet-web'
    addressPrefix: cidrSubnet(addressPrefix, 24, 1)
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
    name: 'snet-func'
    addressPrefix: cidrSubnet(addressPrefix, 24, 2)
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
    name: 'snet-data'
    addressPrefix: cidrSubnet(addressPrefix, 24, 3)
    delegations: []
  }
]

// ── NSG ──────────────────────────────────────────────────────────────

resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-snet-web'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-AppGW-Inbound'
        properties: {
          priority: 100
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: cidrSubnet(addressPrefix, 24, 0)
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          protocol: '*'
          access: 'Deny'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// ── Virtual Network ───────────────────────────────────────────────────

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [ addressPrefix ]
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
        delegations: subnet.delegations
        networkSecurityGroup: subnet.name == 'snet-web' ? {
          id: nsgWeb.id
        } : null
        privateEndpointNetworkPolicies: 'Disabled'
      }
    }]
  }
}

// ── Outputs ───────────────────────────────────────────────────────────

output vnetId string = vnet.id
output vnetName string = vnet.name
output webSubnetId string = vnet.properties.subnets[1].id
output dataSubnetId string = vnet.properties.subnets[3].id
```

---

## starter code: modules/security/key-vault.bicep

```bicep
// modules/security/key-vault.bicep

@description('Azure region')
param location string

@description('Key Vault name (globally unique, 3-24 chars)')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Tags')
param tags object

@description('SKU: standard or premium (premium supports HSM)')
@allowed(['standard', 'premium'])
param sku string = 'standard'

@description('Object ID of the current deployer (for initial access)')
param deployerObjectId string = ''

// ── Key Vault ─────────────────────────────────────────────────────────

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: sku
    }
    tenantId: tenant().tenantId
    enableRbacAuthorization: true          // Gebruik RBAC, niet legacy access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: true            // Vereist voor CMK gebruik
    publicNetworkAccess: 'Disabled'        // Alleen via Private Endpoint
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
    }
  }
}

// ── Diagnostics ───────────────────────────────────────────────────────
// TODO: voeg Log Analytics workspace referentie toe voor audit logging

// ── Outputs ───────────────────────────────────────────────────────────

output keyVaultId string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
```

---

## opdrachttaken

Schrijf de volgende modules **volledig** (de starter code hierboven is enkel een voorbeeld):

| Module | Bestand | Status |
|---|---|---|
| Spoke VNet + NSG's | `modules/network/spoke-vnet.bicep` | Starter gegeven ↑ |
| App Service Plan | `modules/compute/app-service-plan.bicep` | ❌ Zelf schrijven |
| App Service (+ Managed Identity + VNet Integration) | `modules/compute/app-service.bicep` | ❌ Zelf schrijven |
| SQL Server | `modules/data/sql-server.bicep` | ❌ Zelf schrijven |
| SQL Database (+ geo-replication) | `modules/data/sql-database.bicep` | ❌ Zelf schrijven |
| Storage Account | `modules/data/storage-account.bicep` | ❌ Zelf schrijven |
| Key Vault | `modules/security/key-vault.bicep` | Starter gegeven ↑ |
| Private Endpoint | `modules/network/private-endpoint.bicep` | ❌ Zelf schrijven |
| main.bicep orchestrator | `main.bicep` | Starter gegeven ↑ |
| Parameters prd | `main.bicepparam` | ❌ Zelf schrijven |
| Parameters dev | `main.dev.bicepparam` | ❌ Zelf schrijven |

---

## vereisten per module

Elke module moet:

- [ ] Parametervalidatie bevatten (`@minLength`, `@maxLength`, `@allowed`, `@description`)
- [ ] Tags propageren
- [ ] Diagnose-instellingen bevatten (koppeling aan Log Analytics)
- [ ] Outputs exporteren die andere modules nodig hebben
- [ ] Geen hardcoded waarden bevatten (alles via parameters of variabelen)
- [ ] Commentaarblokken hebben voor leesbaarheid

---

## app service module — vereisten

De App Service module moet het volgende bevatten:

```bicep
// Vereiste eigenschappen:
// - System Assigned Managed Identity (identity: { type: 'SystemAssigned' })
// - VNet Integration (virtualNetworkSubnetId)
// - HTTPS only: true
// - Minimum TLS: '1.2'
// - Always On: true (voor prd)
// - Health check path: '/health'
// - App settings die verwijzen naar Key Vault via Key Vault references:
//   '@Microsoft.KeyVault(SecretUri=...)' syntax
// - Deployment slots: staging slot voor prd
// - Diagnose settings naar Log Analytics
```

---

## sql server module — vereisten

```bicep
// Vereiste eigenschappen:
// - Entra ID (Azure AD) authenticatie als primary admin
// - Geen SQL authenticatie als primary (optioneel als fallback)
// - Public network access: Disabled
// - Minimal TLS version: '1.2'
// - Vulnerability assessment (indien Defender for SQL actief)
// - Transparent Data Encryption: Enabled
```

---

## beoordelingscriteria (10 punten)

| Criterium | Punten |
|---|---|
| Modulaire structuur aanwezig en correct | 2 |
| main.bicep roept alle modules aan met correcte parameters | 2 |
| Elke module heeft parametervalidatie en outputs | 2 |
| Security properties correct (HTTPS, PNA Disabled, Managed Identity) | 2 |
| Parameters bestanden (prd + dev) aanwezig | 1 |
| Naamgevingsconventie consistent toegepast | 1 |

---

_Ga verder naar [`../06-cicd/README.md`](../06-cicd/README.md)_

---

_delaware cloud practice — we commit. we deliver._
