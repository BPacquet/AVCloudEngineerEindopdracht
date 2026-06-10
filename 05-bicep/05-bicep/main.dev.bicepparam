// =============================================================================
// main.dev.bicepparam — Development/Test parameters
// -----------------------------------------------------------------------------
// Dev/Test pricing: B2 App Service SKU | Standard_LRS storage | geen geo-rep
// Deployment:
//   export SQL_ADMIN_PASSWORD_DEV="<wachtwoord>"
//   az deployment sub create \
//     --location westeurope \
//     --template-file main.bicep \
//     --parameters main.dev.bicepparam
// =============================================================================

using './main.bicep'

// ── Omgeving ──────────────────────────────────────────────────────
param environment  = 'dev'
param location     = 'westeurope'
param locationCode = 'weu'
param appName      = 'contoso'

// ── Identiteit ────────────────────────────────────────────────────
// Object ID van de Entra ID groep 'contoso-developers'
// Minder rechten dan prd — geen PIM vereist voor dev omgeving
param keyVaultAdminObjectId = '<dev-team-group-object-id>'
param aadAdminGroupObjectId = '<dev-team-group-object-id>'
param aadAdminGroupName     = 'contoso-developers'

// ── SQL MI ────────────────────────────────────────────────────────
param sqlAdminLogin    = 'contoso-dev-admin'
param sqlAdminPassword = readEnvironmentVariable('SQL_ADMIN_PASSWORD_DEV')

// ── Log Analytics ─────────────────────────────────────────────────
// Zelfde LAW als prd — dev-logs gaan naar dezelfde workspace
param logAnalyticsWorkspaceId = '/subscriptions/<mgmt-sub-id>/resourceGroups/rg-contoso-mgmt/providers/Microsoft.OperationalInsights/workspaces/law-contoso-mgmt'

// ── Geo-replicatie ────────────────────────────────────────────────
// Geen geo-replicatie in dev — te duur en niet nodig
param drServerName = ''
param drLocation   = 'northeurope'

// ── Tags ──────────────────────────────────────────────────────────
param tags = {
  Environment:        'dev'
  Application:        'contoso-manufacturing'
  Owner:              'bjorn.pacquet@contoso.be'
  CostCenter:         'CC-DEV-001'
  DataClassification: 'internal'
  ManagedBy:          'bicep'
}
