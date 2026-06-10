// =============================================================================
// main.bicep — Contoso Manufacturing Azure Infrastructure Orchestrator
// delaware cloud practice
// -----------------------------------------------------------------------------
// Architectuur: Hub-Spoke ALZ Corp | West Europe (prd) | North Europe (dr)
// Resources   : App Service P2v3 | SQL MI GP 8vCore | Azure Firewall Premium
// Modules     : network/ compute/ data/ security/
// =============================================================================

targetScope = 'subscription'

// ── Parameters ───────────────────────────────────────────────────
@description('Omgeving: dev, tst of prd')
@allowed(['dev', 'tst', 'prd'])
param environment string

@description('Primaire Azure regio')
param location string = 'westeurope'

@description('Korte locatiecode voor naamgeving — bv. weu')
@minLength(2)
@maxLength(5)
param locationCode string = 'weu'

@description('Applicatienaam — bv. contoso')
@minLength(1)
@maxLength(15)
param appName string = 'contoso'

@description('Object ID van de Entra ID groep voor Key Vault Administrator toegang')
param keyVaultAdminObjectId string

@description('Object ID van de Entra ID groep voor SQL MI Azure AD administrator')
param aadAdminGroupObjectId string

@description('Naam van de Entra ID groep voor SQL MI Azure AD administrator')
param aadAdminGroupName string

@description('SQL MI administrator login — enkel voor initiële setup')
param sqlAdminLogin string = 'contoso-sql-admin'

@description('SQL MI administrator wachtwoord — via omgevingsvariabele in pipeline')
@secure()
param sqlAdminPassword string

@description('Resource ID van de Log Analytics Workspace (law-contoso-mgmt)')
param logAnalyticsWorkspaceId string

@description('Naam van de DR SQL MI — leeg = geen geo-replicatie (dev)')
param drServerName string = ''

@description('DR Azure regio')
param drLocation string = 'northeurope'

@description('Tags die op alle resources worden toegepast')
param tags object = {
  Environment:        environment
  Application:        appName
  Owner:              'bjorn.pacquet@contoso.be'
  CostCenter:         'CC-IT-001'
  DataClassification: 'internal'
  ManagedBy:          'bicep'
}

// ── Variables ────────────────────────────────────────────────────
var prefix            = '${appName}-${environment}'
var hubVnetPrefix     = '10.0.0.0/16'
var spokeVnetPrefix   = '10.20.0.0/16'
var appServiceSku     = environment == 'prd' ? 'P2v3' : 'B2'
var storageSku        = environment == 'prd' ? 'Standard_ZRS' : 'Standard_LRS'

// ── Resource Groups ───────────────────────────────────────────────
resource rgNetworking 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name:     'rg-${prefix}-networking'
  location: location
  tags:     tags
}

resource rgFrontend 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name:     'rg-${prefix}-frontend'
  location: location
  tags:     tags
}

resource rgData 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name:     'rg-${prefix}-data'
  location: location
  tags:     tags
}

resource rgSecurity 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name:     'rg-${prefix}-security'
  location: location
  tags:     tags
}

resource rgMonitoring 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name:     'rg-${prefix}-monitoring'
  location: location
  tags:     tags
}

// ── Modules: Netwerk ─────────────────────────────────────────────
module hubVnet 'modules/network/hub-vnet.bicep' = {
  name:  'deploy-hub-vnet'
  scope: rgNetworking
  params: {
    location:      location
    vnetName:      'vnet-${locationCode}-hub-${environment}'
    addressPrefix: hubVnetPrefix
    tags:          tags
  }
}

module spokeVnet 'modules/network/spoke-vnet.bicep' = {
  name:  'deploy-spoke-vnet'
  scope: rgNetworking
  params: {
    location:      location
    vnetName:      'vnet-${locationCode}-spoke-${environment}'
    addressPrefix: spokeVnetPrefix
    tags:          tags
  }
}

// ── Modules: Security ─────────────────────────────────────────────
module managedIdentity 'modules/security/managed-identity.bicep' = {
  name:  'deploy-managed-identity'
  scope: rgSecurity
  params: {
    location: location
    miName:   'mi-${prefix}-app'
    tags:     tags
  }
}

module keyVault 'modules/security/key-vault.bicep' = {
  name:  'deploy-key-vault'
  scope: rgSecurity
  params: {
    location:                        location
    keyVaultName:                    'kv-${appName}-${environment}'
    adminObjectId:                   keyVaultAdminObjectId
    appManagedIdentityPrincipalId:   managedIdentity.outputs.principalId
    softDeleteDays:                  90
    privateEndpointSubnetId:         spokeVnet.outputs.dataSubnetId
    logAnalyticsWorkspaceId:         logAnalyticsWorkspaceId
    tags:                            tags
  }
}

// ── Modules: Compute ──────────────────────────────────────────────
module appServicePlan 'modules/compute/app-service-plan.bicep' = {
  name:  'deploy-app-service-plan'
  scope: rgFrontend
  params: {
    location:                location
    planName:                'asp-${prefix}'
    sku:                     appServiceSku
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tags:                    tags
  }
}

module webApp 'modules/compute/app-service.bicep' = {
  name:  'deploy-web-app'
  scope: rgFrontend
  params: {
    location:                location
    appName:                 'web-${prefix}'
    appServicePlanId:        appServicePlan.outputs.planId
    keyVaultName:            keyVault.outputs.keyVaultName
    keyVaultUri:             keyVault.outputs.keyVaultUri
    vnetSubnetId:            spokeVnet.outputs.webSubnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tags:                    tags
  }
}

// ── Modules: Data ─────────────────────────────────────────────────
module storageAccount 'modules/data/storage-account.bicep' = {
  name:  'deploy-storage-account'
  scope: rgData
  params: {
    location:                location
    storageAccountName:      'st${appName}${environment}001'
    storageSku:              storageSku
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tags:                    tags
  }
}

module sqlServer 'modules/data/sql-server.bicep' = {
  name:  'deploy-sql-server'
  scope: rgData
  params: {
    location:                location
    serverName:              'sql-${prefix}-001'
    adminLogin:              sqlAdminLogin
    adminPassword:           sqlAdminPassword
    subnetId:                spokeVnet.outputs.sqlSubnetId
    aadAdminGroupObjectId:   aadAdminGroupObjectId
    aadAdminGroupName:       aadAdminGroupName
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tags:                    tags
  }
}

module sqlDatabase 'modules/data/sql-database.bicep' = {
  name:  'deploy-sql-database'
  scope: rgData
  params: {
    location:                location
    drLocation:              drLocation
    serverName:              sqlServer.outputs.serverName
    drServerName:            drServerName
    databaseName:            'sqldb-${prefix}'
    failoverGroupName:       'fog-${prefix}'
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tags:                    tags
  }
}

// ── Modules: Private Endpoints ────────────────────────────────────
module privateEndpoints 'modules/network/private-endpoint.bicep' = {
  name:  'deploy-private-endpoints'
  scope: rgNetworking
  params: {
    location:         location
    subnetId:         spokeVnet.outputs.dataSubnetId
    keyVaultId:       keyVault.outputs.keyVaultId
    storageAccountId: storageAccount.outputs.storageAccountId
    hubVnetId:        hubVnet.outputs.vnetId
    prefix:           prefix
    tags:             tags
  }
}

// ── Outputs ───────────────────────────────────────────────────────
@description('Naam van de App Service')
output webAppName string = webApp.outputs.appName

@description('Standaard hostname van de App Service')
output webAppHostname string = webApp.outputs.defaultHostname

@description('Naam van de SQL Managed Instance')
output sqlServerName string = sqlServer.outputs.serverName

@description('FQDN van de SQL Managed Instance')
output sqlServerFqdn string = sqlServer.outputs.fqdn

@description('URI van de Key Vault')
output keyVaultUri string = keyVault.outputs.keyVaultUri

@description('Naam van het Storage Account')
output storageAccountName string = storageAccount.outputs.storageAccountName

@description('Principal ID van de App Managed Identity — voor RBAC toewijzingen')
output managedIdentityPrincipalId string = managedIdentity.outputs.principalId
