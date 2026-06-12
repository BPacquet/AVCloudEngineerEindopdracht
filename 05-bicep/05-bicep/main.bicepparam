using './main.bicep'

param environment = 'prd'
param location = 'westeurope'
param locationCode = 'weu'
param appName = 'contoso'

// Vul deze object IDs in voor een echte productie-deployment.
// Leeg laten mag voor een technische testdeployment, dan worden deze RBAC/AAD-admin stappen overgeslagen.
param keyVaultAdminObjectId = ''
param aadAdminGroupObjectId = ''
param aadAdminGroupName = ''

param sqlAdminLogin = 'contososqladmin'
param sqlAdminPassword = readEnvironmentVariable('SQL_ADMIN_PASSWORD')

// Vul in wanneer er al een centrale Log Analytics Workspace bestaat.
param logAnalyticsWorkspaceId = ''

param tags = {
  Environment: 'prd'
  Application: 'contoso-manufacturing'
  Owner: 'team-cloud@contoso.be'
  CostCenter: 'CC-IT-001'
  DataClassification: 'confidential'
  ManagedBy: 'bicep'
}
