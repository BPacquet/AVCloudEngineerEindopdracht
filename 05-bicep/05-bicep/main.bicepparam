// =============================================================================
// main.bicepparam — Productie parameters
// -----------------------------------------------------------------------------
// Deployment:
//   export SQL_ADMIN_PASSWORD="<wachtwoord>"
//   az deployment sub create \
//     --location westeurope \
//     --template-file main.bicep \
//     --parameters main.bicepparam
// =============================================================================

using './main.bicep'

// ── Omgeving ──────────────────────────────────────────────────────
param environment  = 'prd'
param location     = 'westeurope'
param locationCode = 'weu'
param appName      = 'contoso'

// ── Identiteit ────────────────────────────────────────────────────
// Object ID van de Entra ID groep 'cloud-platform-engineers'
// Ophalen: az ad group show --group "cloud-platform-engineers" --query id -o tsv
param keyVaultAdminObjectId  = '<entra-group-object-id>'
param aadAdminGroupObjectId  = '<entra-group-object-id>'
param aadAdminGroupName      = 'cloud-platform-engineers'

// ── SQL MI ────────────────────────────────────────────────────────
param sqlAdminLogin    = 'contoso-sql-admin'
// Wachtwoord via omgevingsvariabele — nooit plaintext in parameterbestand
// az keyvault secret set --vault-name kv-bootstrap --name sql-admin-pw --value '<pw>'
param sqlAdminPassword = readEnvironmentVariable('SQL_ADMIN_PASSWORD')

// ── Log Analytics ─────────────────────────────────────────────────
// Resource ID van de bestaande Log Analytics Workspace in Management sub
// Ophalen: az monitor log-analytics workspace show \
//          --resource-group rg-contoso-mgmt \
//          --workspace-name law-contoso-mgmt --query id -o tsv
param logAnalyticsWorkspaceId = '/subscriptions/<mgmt-sub-id>/resourceGroups/rg-contoso-mgmt/providers/Microsoft.OperationalInsights/workspaces/law-contoso-mgmt'

// ── Geo-replicatie ────────────────────────────────────────────────
// DR SQL MI naam — moet al bestaan in North Europe subscriptie
param drServerName = 'sql-contoso-prd-dr-001'
param drLocation   = 'northeurope'

// ── Tags ──────────────────────────────────────────────────────────
// Verplichte tags conform Azure Policy (contoso-deny-missing-tag-*)
// Afwijkende waarden worden geblokkeerd door Deny-policies
param tags = {
  Environment:        'prd'
  Application:        'contoso-manufacturing'
  Owner:              'bjorn.pacquet@contoso.be'
  CostCenter:         'CC-MFG-001'
  DataClassification: 'confidential'
  ManagedBy:          'bicep'
}
