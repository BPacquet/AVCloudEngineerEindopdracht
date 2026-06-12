param location string
param webAppName string
param appServicePlanId string
param keyVaultUri string
param sqlMiFqdn string
param databaseName string
param vnetSubnetId string
param isPrd bool
param logAnalyticsWorkspaceId string = ''
param tags object

var sqlConnectionString = 'Server=${sqlMiFqdn},1433;Database=${databaseName};Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;'

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  tags: tags
  kind: 'app'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    virtualNetworkSubnetId: vnetSubnetId
    siteConfig: {
      netFrameworkVersion: 'v4.8'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      alwaysOn: isPrd
      healthCheckPath: '/health'
      vnetRouteAllEnabled: true
      appSettings: [
        { name: 'KEY_VAULT_URI'
          value: keyVaultUri }
        { name: 'SAP_API_KEY'
          value: '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/sap-integration-key/)' }
        { name: 'SERVICEBUS_CONNECTION'
          value: '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/servicebus-connection/)' }
        { name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'false' }
      ]
      connectionStrings: [
        {
          name: 'DefaultConnection'
          connectionString: sqlConnectionString
          type: 'SQLServer'
        }
      ]
    }
  }
}

resource stagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = if (isPrd) {
  parent: webApp
  name: 'staging'
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly: true
    siteConfig: {
      netFrameworkVersion: 'v4.8'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      alwaysOn: true
    }
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${webAppName}-diagnostics'
  scope: webApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'AppServiceHTTPLogs'
        enabled: true }
      { category: 'AppServiceConsoleLogs'
        enabled: true }
      { category: 'AppServiceAppLogs'
        enabled: true }
      { category: 'AppServiceAuditLogs'
        enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics'
        enabled: true }
    ]
  }
}

output webAppName string = webApp.name
output webAppId string = webApp.id
output defaultHostName string = webApp.properties.defaultHostName
output principalId string = webApp.identity.principalId
