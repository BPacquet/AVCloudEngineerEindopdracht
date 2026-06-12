param location string
param functionAppName string
param appServicePlanId string
param storageAccountName string
param keyVaultUri string
param vnetSubnetId string
param logAnalyticsWorkspaceId string = ''
param tags object

resource storage 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: storageAccountName
}

var storageConnection = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  tags: tags
  kind: 'functionapp'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    virtualNetworkSubnetId: vnetSubnetId
    siteConfig: {
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      vnetRouteAllEnabled: true
      appSettings: [
        { name: 'AzureWebJobsStorage'
          value: storageConnection }
        { name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4' }
        { name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet' }
        { name: 'KEY_VAULT_URI'
          value: keyVaultUri }
        { name: 'SERVICEBUS_CONNECTION'
          value: '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/servicebus-connection/)' }
      ]
    }
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${functionAppName}-diagnostics'
  scope: functionApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'FunctionAppLogs'
        enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics'
        enabled: true }
    ]
  }
}

output functionAppName string = functionApp.name
output functionAppId string = functionApp.id
output principalId string = functionApp.identity.principalId
