param managedInstanceName string
param location string
param databaseName string = 'ContosoDB'
param logAnalyticsWorkspaceId string = ''
param tags object

resource sqlMi 'Microsoft.Sql/managedInstances@2023-08-01-preview' existing = {
  name: managedInstanceName
}

resource database 'Microsoft.Sql/managedInstances/databases@2023-08-01-preview' = {
  parent: sqlMi
  name: databaseName
  location: location
  tags: tags
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

resource shortTermRetention 'Microsoft.Sql/managedInstances/databases/backupShortTermRetentionPolicies@2023-08-01-preview' = {
  parent: database
  name: 'default'
  properties: {
    retentionDays: 35
  }
}

resource longTermRetention 'Microsoft.Sql/managedInstances/databases/backupLongTermRetentionPolicies@2023-08-01-preview' = {
  parent: database
  name: 'default'
  properties: {
    weeklyRetention: 'P4W'
    monthlyRetention: 'P12M'
    yearlyRetention: 'P3Y'
    weekOfYear: 1
  }
}

resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(logAnalyticsWorkspaceId)) {
  name: '${databaseName}-diagnostics'
  scope: database
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      { category: 'SQLSecurityAuditEvents'
        enabled: true }
    ]
    metrics: [
      { category: 'AllMetrics'
        enabled: true }
    ]
  }
}

output databaseName string = database.name
output databaseId string = database.id
