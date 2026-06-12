targetScope = 'subscription'

@allowed(['dev','tst','prd'])
param environment string
param location string = 'westeurope'
param locationCode string = 'weu'
param appName string = 'contoso'
param keyVaultAdminObjectId string = ''
param aadAdminGroupObjectId string = ''
param aadAdminGroupName string = ''
param sqlAdminLogin string = 'contososqladmin'
@secure()
param sqlAdminPassword string
param logAnalyticsWorkspaceId string = ''
param tags object = {
  Environment: environment
  Application: 'contoso-manufacturing'
  Owner: 'team-cloud@contoso.be'
  CostCenter: 'CC-IT-001'
  DataClassification: environment == 'prd' ? 'confidential' : 'internal'
  ManagedBy: 'bicep'
}

var prefix = '${appName}-${environment}'
var isPrd = environment == 'prd'
var appServiceSku = isPrd ? 'P2v3' : 'B2'
var storageSku = isPrd ? 'Standard_ZRS' : 'Standard_LRS'
var uniqueSuffix = substring(uniqueString(subscription().id, environment, appName), 0, 6)

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

module hubVnet 'modules/network/hub-vnet.bicep' = {
  name: 'hub-vnet-${environment}'
  scope: rgNetworking
  params: {
    location: location
    vnetName: 'vnet-${locationCode}-hub-${environment}'
    addressPrefix: '10.0.0.0/16'
    tags: tags
  }
}

module spokeVnet 'modules/network/spoke-vnet.bicep' = {
  name: 'spoke-vnet-${environment}'
  scope: rgNetworking
  params: {
    location: location
    vnetName: 'vnet-${locationCode}-spoke-${environment}'
    addressPrefix: '10.20.0.0/16'
    tags: tags
  }
}

module keyVault 'modules/security/key-vault.bicep' = {
  name: 'keyvault-${environment}'
  scope: rgSecurity
  params: {
    location: location
    keyVaultName: 'kv-${appName}-${environment}-${uniqueSuffix}'
    adminObjectId: keyVaultAdminObjectId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tags: tags
  }
}

module appServicePlan 'modules/compute/app-service-plan.bicep' = {
  name: 'asp-${environment}'
  scope: rgFrontend
  params: {
    location: location
    planName: 'asp-${prefix}'
    skuName: appServiceSku
    tags: tags
  }
}

module storageAccount 'modules/data/storage-account.bicep' = {
  name: 'storage-${environment}'
  scope: rgData
  params: {
    location: location
    storageAccountName: toLower('st${appName}${environment}${uniqueSuffix}')
    storageSku: storageSku
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tags: tags
  }
}

module sqlMi 'modules/data/sql-server.bicep' = {
  name: 'sqlmi-${environment}'
  scope: rgData
  params: {
    location: location
    managedInstanceName: 'sqlmi-${prefix}-${uniqueSuffix}'
    adminLogin: sqlAdminLogin
    adminPassword: sqlAdminPassword
    subnetId: spokeVnet.outputs.sqlSubnetId
    aadAdminGroupObjectId: aadAdminGroupObjectId
    aadAdminGroupName: aadAdminGroupName
    vCores: isPrd ? 8 : 4
    storageSizeInGB: isPrd ? 1024 : 256
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tags: tags
  }
}

module sqlDb 'modules/data/sql-database.bicep' = {
  name: 'sqldb-${environment}'
  scope: rgData
  params: {
    managedInstanceName: sqlMi.outputs.managedInstanceName
    location: location
    databaseName: 'ContosoDB'
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tags: tags
  }
}

module webApp 'modules/compute/app-service.bicep' = {
  name: 'webapp-${environment}'
  scope: rgFrontend
  params: {
    location: location
    webAppName: 'web-${prefix}-${uniqueSuffix}'
    appServicePlanId: appServicePlan.outputs.planId
    keyVaultUri: keyVault.outputs.keyVaultUri
    sqlMiFqdn: sqlMi.outputs.fqdn
    databaseName: sqlDb.outputs.databaseName
    vnetSubnetId: spokeVnet.outputs.webSubnetId
    isPrd: isPrd
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tags: tags
  }
}

module functionApp 'modules/compute/function-app.bicep' = {
  name: 'func-${environment}'
  scope: rgFrontend
  params: {
    location: location
    functionAppName: 'fn-${prefix}-${uniqueSuffix}'
    appServicePlanId: appServicePlan.outputs.planId
    storageAccountName: storageAccount.outputs.storageAccountName
    keyVaultUri: keyVault.outputs.keyVaultUri
    vnetSubnetId: spokeVnet.outputs.funcSubnetId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
    tags: tags
  }
}

module kvRbacWeb 'modules/security/key-vault-rbac.bicep' = {
  name: 'kv-rbac-web-${environment}'
  scope: rgSecurity
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    principalId: webApp.outputs.principalId
  }
}

module kvRbacFunc 'modules/security/key-vault-rbac.bicep' = {
  name: 'kv-rbac-func-${environment}'
  scope: rgSecurity
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    principalId: functionApp.outputs.principalId
  }
}

module privateEndpoints 'modules/network/private-endpoints.bicep' = {
  name: 'private-endpoints-${environment}'
  scope: rgNetworking
  params: {
    location: location
    prefix: prefix
    subnetId: spokeVnet.outputs.dataSubnetId
    spokeVnetId: spokeVnet.outputs.vnetId
    keyVaultId: keyVault.outputs.keyVaultId
    storageAccountId: storageAccount.outputs.storageAccountId
    webAppId: webApp.outputs.webAppId
    tags: tags
  }
}

output webAppName string = webApp.outputs.webAppName
output webAppHostname string = webApp.outputs.defaultHostName
output functionAppName string = functionApp.outputs.functionAppName
output sqlManagedInstanceName string = sqlMi.outputs.managedInstanceName
output sqlManagedInstanceFqdn string = sqlMi.outputs.fqdn
output keyVaultUri string = keyVault.outputs.keyVaultUri
output storageAccountName string = storageAccount.outputs.storageAccountName
