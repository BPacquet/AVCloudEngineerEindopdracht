// main.bicepparam — Productie parameters
// Pas aan naar jouw omgeving

using './main.bicep'

param environment = 'prd'
param location = 'westeurope'
param locationCode = 'weu'
param appName = 'contoso'
param tags = {
  Environment: 'prd'
  Application: 'contoso-manufacturing'
  Owner: 'team-cloud@contoso.be'
  CostCenter: 'CC-IT-001'
  DataClassification: 'internal'
  ManagedBy: 'bicep'
}
