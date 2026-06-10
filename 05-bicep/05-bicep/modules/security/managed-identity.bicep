// modules/security/managed-identity.bicep
// User-assigned Managed Identity — gedeeld door App Service en Functions
// Alternatief: system-assigned per resource (zie app-service.bicep)
// Voordeel user-assigned: één RBAC-toewijzing voor meerdere resources

param location string
param miName   string
param tags     object

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name:     miName
  location: location
  tags:     tags
}

// ── Outputs — gebruikt door andere modules voor RBAC ──────────────
output id          string = managedIdentity.id
output principalId string = managedIdentity.properties.principalId
output clientId    string = managedIdentity.properties.clientId
output name        string = managedIdentity.name
