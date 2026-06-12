using './main.bicep'

param environment = 'dev'
param location = 'westeurope'
param locationCode = 'weu'
param appName = 'contoso'
param keyVaultAdminObjectId = ''
param aadAdminGroupObjectId = ''
param aadAdminGroupName = ''
param sqlAdminLogin = 'contosodevadmin'
param sqlAdminPassword = readEnvironmentVariable('SQL_ADMIN_PASSWORD_DEV')
param logAnalyticsWorkspaceId = ''

param tags = {
  Environment: 'dev'
  Application: 'contoso-manufacturing'
  Owner: 'team-cloud@contoso.be'
  CostCenter: 'CC-DEV-001'
  DataClassification: 'internal'
  ManagedBy: 'bicep'
}
