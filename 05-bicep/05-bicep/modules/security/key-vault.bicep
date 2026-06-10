// modules/security/key-vault.bicep
// Key Vault — Standard of Premium tier | RBAC model (niet Access Policies)
// Soft-delete 90 dagen | Purge protection aan (Azure Policy Deny als uit)
// Publieke toegang uitgeschakeld — enkel via Private Endpoint 10.20.3.6
// NIS2: Art. 21(2)(c) continuïteit · Art. 21(2)(e) toegangscontrole

@description('Azure region')
param location string

@description('Key Vault name (globally unique, 3-24 chars) — kv-contoso-prd')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Tags')
param tags object

@description('SKU: standard of premium (premium ondersteunt HSM-backed keys)')
@allowed(['standard', 'premium'])
param sku string = 'standard'

@description('Object ID van Cloud Platform Engineer groep in Entra ID — voor Key Vault Administrator rol')
param adminObjectId string

@description('Principal ID van de App Service + Functions Managed Identity — voor Key Vault Secrets User rol')
param appManagedIdentityPrincipalId string

@description('Soft-delete retentie in dagen — 90 is maximum en ALZ aanbeveling')
@minValue(7)
@maxValue(90)
param softDeleteDays int = 90

@description('Subnet ID van snet-spoke-data voor Private Endpoint')
param privateEndpointSubnetId string

// ── Key Vault ─────────────────────────────────────────────────────
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name:     keyVaultName
  location: location
  tags:     tags
  properties: {
    sku: {
      family: 'A'
      name:   sku              // 'standard' voor prd | 'premium' als HSM vereist
    }
    tenantId: tenant().tenantId

    // RBAC model — aanbevolen boven klassieke Access Policies
    // Ondersteunt PIM, Conditional Access en audit via Entra ID
    enableRbacAuthorization: true

    // Soft-delete + purge protection — NIS2 Art. 21(2)(c) continuïteit
    // Azure Policy Deny als enablePurgeProtection = false
    enableSoftDelete:          true
    softDeleteRetentionInDays: softDeleteDays
    enablePurgeProtection:     true

    // Publieke toegang uitgeschakeld — enkel via Private Endpoint
    // Azure Policy: contoso-deny-missing-tag-environment controleert ook hier
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      defaultAction: 'Deny'
      bypass:        'AzureServices'  // Toestaan voor Automation Account en ARM
    }
  }
}

// ── RBAC: Key Vault Administrator (Cloud Platform Engineer) ───────
// Via PIM Eligible in productie — niet permanent actief
resource rbacAdmin 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(adminObjectId)) {
  name:  guid(keyVault.id, adminObjectId, 'kv-administrator')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '00482a5a-887f-4fb3-b363-3b7fe8e74483'  // Key Vault Administrator
    )
    principalId:   adminObjectId
    principalType: 'Group'
    description:   'Cloud Platform Engineer groep — PIM Eligible in productie'
  }
}

// ── RBAC: Key Vault Secrets User (App Managed Identity) ───────────
// Data plane — enkel getSecret, geen set/delete
// Managed Identity van App Service en Functions
resource rbacApp 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(appManagedIdentityPrincipalId)) {
  name:  guid(keyVault.id, appManagedIdentityPrincipalId, 'kv-secrets-user')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'  // Key Vault Secrets User
    )
    principalId:   appManagedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    description:   'App Service + Functions Managed Identity — read-only secrets'
  }
}

// ── Private Endpoint (10.20.3.6) ─────────────────────────────────
resource peKv 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name:     'pe-${keyVaultName}'
  location: location
  tags:     tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'conn-${keyVaultName}'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds:             ['vault']
        }
      }
    ]
  }
}

// ── Private DNS Zone ──────────────────────────────────────────────
resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name:     'privatelink.vaultcore.azure.net'
  location: 'global'
  tags:     tags
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: peKv
  name:   'zonegroup-kv'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'kv-zone'
        properties: {
          privateDnsZoneId: dnsZone.id
        }
      }
    ]
  }
}

// ── Diagnostics naar Log Analytics ───────────────────────────────
// Alle Key Vault operaties loggen — NIS2 Art. 21(2)(b) monitoring
// TODO: workspaceId parameter toevoegen voor koppeling aan law-contoso-mgmt
//       az monitor log-analytics workspace show --resource-group rg-contoso-mgmt
//       --workspace-name law-contoso-mgmt --query id -o tsv
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name:  '${keyVaultName}-diagnostics'
  scope: keyVault
  properties: {
    // workspaceId: logAnalyticsWorkspaceId  ← parameter toevoegen indien gewenst
    logs: [
      {
        category: 'AuditEvent'   // Elke secret-aanroep gelogd
        enabled:  true
        retentionPolicy: {
          enabled: false
          days:    0             // Retentie beheerd door Log Analytics workspace
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled:  true
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────
output keyVaultId   string = keyVault.id
output keyVaultName string = keyVault.name
output keyVaultUri  string = keyVault.properties.vaultUri
