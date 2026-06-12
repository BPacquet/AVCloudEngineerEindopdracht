param location string
param managedInstanceName string
param adminLogin string
@secure()
param adminPassword string
param subnetId string
param aadAdminGroupObjectId string = ''
param aadAdminGroupName string = ''
param vCores int = 8
param storageSizeInGB int = 1024
param logAnalyticsWorkspaceId string = ''
param tags object

resource sqlMi 'Microsoft.Sql/managedInstances@2023-08-01-preview' = {
  name: managedInstanceName
  location: location
  tags: tags
  sku: {
    name: 'GP_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: vCores
  }
  identity: { type: 'SystemAssigned' }
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    subnetId: subnetId
    licenseType: 'BasePrice'
    vCores: vCores
    storageSizeInGB: storageSizeInGB
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    publicDataEndpointEnabled: false
    minimalTlsVersion: '1.2'
    proxyOverride: 'Default'
    timezoneId: 'Romance Standard Time'
  }
}

resource aadAdmin 'Microsoft.Sql/managedInstances/administrators@2023-08-01-preview' = if (!empty(aadAdminGroupObjectId)) {
  parent: sqlMi
  name: 'ActiveDirectory'
  properties: {
    administratorType: 'ActiveDirectory'
    login: aadAdminGroupName
    sid: aadAdminGroupObjectId
    tenantId: tenant().tenantId
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${managedInstanceName}-diagnostics'
  scope: sqlMi
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'ResourceUsageStats'
        enabled: true }
      { category: 'SQLSecurityAuditEvents'
        enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics'
        enabled: true }
    ]
  }
}

output managedInstanceName string = sqlMi.name
output managedInstanceId string = sqlMi.id
output fqdn string = sqlMi.properties.fullyQualifiedDomainName
output principalId string = sqlMi.identity.principalId
