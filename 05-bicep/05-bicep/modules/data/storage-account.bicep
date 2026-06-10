// =============================================================================
// modules/data/storage-account.bicep
// Storage Account — ZRS (Zone-Redundant) | Hot tier
// -----------------------------------------------------------------------------
// Naam      : stcontoso{env}001 — geen koppelteken (Azure-beperking: a-z0-9, max 24)
// Replicatie: ZRS — ALZ vereiste productie, beschermt tegen AZ-storing
// Toegang   : uitgeschakeld — enkel via Private Endpoint (snet-spoke-data)
// Lifecycle : Hot → Cool na 30 dagen voor rapporten-container
// =============================================================================

// ── Parameters ───────────────────────────────────────────────────
@description('Azure regio voor de resource')
param location string

@description('Naam van het Storage Account — max 24 tekens, enkel lowercase letters en cijfers, geen koppelteken')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('SKU voor storage replicatie: Standard_ZRS (prd) of Standard_LRS (dev)')
@allowed(['Standard_ZRS', 'Standard_LRS', 'Standard_GRS'])
param storageSku string = 'Standard_ZRS'

@description('Toegestane IPs voor netwerk-ACLs — leeg = alleen Private Endpoint')
param allowedIpRanges array = []

@description('Resource ID van de Log Analytics Workspace voor diagnostics')
param logAnalyticsWorkspaceId string

@description('Tags die op alle resources worden toegepast')
param tags object

// ── Variables ────────────────────────────────────────────────────
// Container namen — worden aangemaakt als sub-resource
var containers = [
  'rapporten'     // Maandelijkse exports — lifecycle: Hot → Cool na 30d
  'uploads'       // Document uploads van applicatie
  'exports'       // Batch exports van Functions Reporter
  'backups'       // Application-level backups (niet RSV)
]

// ── Storage Account ───────────────────────────────────────────────
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name:     storageAccountName
  location: location
  tags:     tags
  kind:     'StorageV2'   // GeneralPurpose v2 — ondersteunt alle features
  sku: {
    // Standard_ZRS: Zone-Redundant — ALZ vereiste voor productie
    // Beschermt tegen uitval van één availability zone in West Europe
    // Standard_LRS: enkel voor dev/tst (geen zone-redundantie nodig)
    name: storageSku
  }
  properties: {
    // ── Beveiliging ────────────────────────────────────────────
    // Publieke toegang uitschakelen — Azure Policy: contoso-deny-storage-public-blob
    publicNetworkAccess:   'Disabled'
    allowBlobPublicAccess: false   // Geen anonieme blob-toegang
    allowSharedKeyAccess:  false   // Enkel Managed Identity / Entra ID

    // TLS 1.2 minimum — Azure Policy: contoso-deny-storage-tls11
    // NIS2 Art. 21(2)(h) — cryptografie in transit
    minimumTlsVersion:        'TLS1_2'
    supportsHttpsTrafficOnly: true

    // ── Soft-delete ────────────────────────────────────────────
    // Blob soft-delete: 30 dagen herstelvenster
    deleteRetentionPolicy: {
      enabled: true
      days:    30
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days:    30
    }

    // ── Versioning ────────────────────────────────────────────
    // Blob versioning: herstel van overschreven bestanden
    // Nuttig voor rapporten die periodiek worden overschreven
    isVersioningEnabled: true

    // ── Netwerk ────────────────────────────────────────────────
    // Default deny — enkel via Private Endpoint of AzureServices bypass
    networkAcls: {
      defaultAction: 'Deny'
      bypass:        'AzureServices'   // Automation Account en ARM mogen door
      ipRules: [for ip in allowedIpRanges: {
        value:  ip
        action: 'Allow'
      }]
      virtualNetworkRules: []
    }

    // ── Access tier ───────────────────────────────────────────
    // Hot: rapporten worden dagelijks geraadpleegd
    // Lifecycle policy verplaatst naar Cool na 30 dagen
    accessTier: 'Hot'

    // ── Hiërarchische namespace ───────────────────────────────
    // false = geen ADLS Gen2 (niet nodig voor Contoso)
    isHnsEnabled: false
  }
}

// ── Blob service configuratie ─────────────────────────────────────
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name:   'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days:    30
    }
    isVersioningEnabled: true
    // Change feed: bijhouden van alle blob-wijzigingen (audit trail)
    changeFeed: {
      enabled:         true
      retentionInDays: 90   // 90 dagen conform Log Analytics hot retentie
    }
  }
}

// ── Containers aanmaken ───────────────────────────────────────────
resource blobContainers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = [
  for container in containers: {
    parent: blobService
    name:   container
    properties: {
      // Geen publieke toegang — private container
      publicAccess: 'None'
      // Immutability policy optioneel uitbreiden voor compliance
    }
  }
]

// ── Lifecycle management policy ───────────────────────────────────
// Rapporten: Hot → Cool na 30 dagen (~€0.010/GB besparing per maand)
// Overige: geen automatische tiering (worden actief gebruikt)
resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
  parent: storageAccount
  name:   'default'
  properties: {
    policy: {
      rules: [
        {
          name:    'rapporten-to-cool'
          enabled: true
          type:    'Lifecycle'
          definition: {
            filters: {
              blobTypes:   ['blockBlob']
              prefixMatch: ['rapporten/']   // Enkel de rapporten-container
            }
            actions: {
              baseBlob: {
                // Verplaats naar Cool na 30 dagen inactiviteit
                tierToCool: {
                  daysAfterModificationGreaterThan: 30
                }
                // Verplaats naar Archive na 365 dagen (optioneel)
                // tierToArchive: { daysAfterModificationGreaterThan: 365 }
              }
              // Verwijder soft-deleted blobs na 30 dagen
              snapshot: {
                delete: {
                  daysAfterCreationGreaterThan: 30
                }
              }
            }
          }
        }
        {
          name:    'exports-to-cool'
          enabled: true
          type:    'Lifecycle'
          definition: {
            filters: {
              blobTypes:   ['blockBlob']
              prefixMatch: ['exports/']
            }
            actions: {
              baseBlob: {
                tierToCool: {
                  daysAfterModificationGreaterThan: 14  // Exports minder lang actief
                }
              }
            }
          }
        }
      ]
    }
  }
}

// ── Diagnostics → Log Analytics ──────────────────────────────────
// Storage diagnostics: alle lees/schrijf/verwijder operaties op blob
// Nuttig voor security audit en anomalie-detectie
// NIS2 Art. 21(2)(b) — monitoring en detectie
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name:  '${storageAccountName}-diagnostics'
  scope: storageAccount
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'Transaction'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
  }
}

// Blob service diagnostics (apart van storage account diagnostics)
resource blobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name:  '${storageAccountName}-blob-diagnostics'
  scope: blobService
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'StorageRead'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        category: 'StorageWrite'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        category: 'StorageDelete'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────
@description('Naam van het Storage Account')
output storageAccountName string = storageAccount.name

@description('Resource ID van het Storage Account')
output storageAccountId string = storageAccount.id

@description('Primaire Blob endpoint URL')
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob

@description('Primaire File endpoint URL')
output fileEndpoint string = storageAccount.properties.primaryEndpoints.file
