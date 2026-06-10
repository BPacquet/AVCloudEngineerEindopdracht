// =============================================================================
// modules/data/sql-server.bicep
// SQL Managed Instance — General Purpose 8 vCore
// -----------------------------------------------------------------------------
// AAD auth  : Entra ID groep als primary admin — geen SQL auth als primary
// AHB       : SQL Server Enterprise SA — ~40% korting (licenseType: BasePrice)
// Netwerk   : publicDataEndpointEnabled = false | TLS 1.2 minimum
// TDE       : Transparent Data Encryption ingeschakeld (service-managed key)
// Defender  : vulnerability assessment via Defender for SQL plan
// Subnet    : snet-sqli-dedicated 10.20.4.0/24 (DEDICATED — geen andere resources)
// =============================================================================

// ── Parameters ───────────────────────────────────────────────────
@description('Azure regio voor de resource')
param location string

@description('Naam van de SQL Managed Instance — bv. sql-contoso-prd-001')
@minLength(1)
@maxLength(63)
param serverName string

@description('SQL administrator login — enkel als fallback tijdens migratie')
@minLength(1)
@maxLength(128)
param adminLogin string

@description('SQL administrator wachtwoord — enkel als fallback, daarna AAD-only')
@secure()
@minLength(16)
param adminPassword string

@description('Resource ID van het dedicated SQL MI subnet (snet-sqli-dedicated)')
param subnetId string

@description('Object ID van de Entra ID groep die SQL MI beheert — bv. cloud-platform-engineers')
param aadAdminGroupObjectId string

@description('Naam van de Entra ID groep die SQL MI beheert')
@minLength(1)
param aadAdminGroupName string

@description('True = AAD-only authenticatie, false = ook SQL auth (gebruik false tijdens migratiefase)')
param aadOnlyAuthentication bool = false

@description('Resource ID van de Log Analytics Workspace voor diagnostics en vulnerability assessment')
param logAnalyticsWorkspaceId string

@description('Storage Account URI voor vulnerability assessment rapporten — bv. https://stcontoso.blob.core.windows.net/')
param vulnerabilityAssessmentStorageUri string = ''

@description('Tags die op alle resources worden toegepast')
param tags object

// ── Variables ────────────────────────────────────────────────────
// 1 TB opslag inbegrepen in GP-tier
// DB groeit naar ~426 GB jaar 3 (280 GB × 1.15^3) — ruim binnen 1 TB
var storageSizeInGB = 1024

// ── SQL Managed Instance ──────────────────────────────────────────
resource sqlManagedInstance 'Microsoft.Sql/managedInstances@2023-02-01-preview' = {
  name:     serverName
  location: location
  tags:     tags
  sku: {
    // General Purpose 8 vCore — benchmark: nodig bij maandafsluiting OLTP + batch
    // Business Critical zou +€1.800/mnd kosten zonder meetbare gain voor Contoso
    name:     'GP_Gen5'
    tier:     'GeneralPurpose'
    family:   'Gen5'
    capacity: 8
  }
  identity: {
    // System-assigned vereist voor AAD authenticatie en TDE CMK (indien gewenst)
    type: 'SystemAssigned'
  }
  properties: {

    // ── Authenticatie ──────────────────────────────────────────
    // SQL authenticatie als fallback — enkel voor initiële setup en migratie
    // Na volledige migratie: zet aadOnlyAuthentication op true
    administratorLogin:         adminLogin
    administratorLoginPassword: adminPassword

    // Entra ID groep als primary admin — geen persoonlijke accounts
    // Cloud Platform Engineer groep heeft via PIM toegang
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType:     'Group'
      login:             aadAdminGroupName
      sid:               aadAdminGroupObjectId
      tenantId:          tenant().tenantId
      // false = ook SQL auth toegestaan (nodig voor migratiefase)
      // true  = AAD-only, geen SQL auth meer mogelijk
      azureADOnlyAuthentication: aadOnlyAuthentication
    }

    // ── Licentie & AHB ────────────────────────────────────────
    // BasePrice = Azure Hybrid Benefit ingeschakeld
    // Vereist: SQL Server Enterprise SA — ~40% korting op licentiedeel
    licenseType: 'BasePrice'

    // ── Netwerk ───────────────────────────────────────────────
    // Dedicated subnet — Microsoft reserveert 16+ IPs voor HA-cluster
    subnetId: subnetId

    // Publiek endpoint uitschakelen — Azure Policy Deny als true
    // NIS2 Art. 21(2)(a) — netwerksegmentatie en Zero-Trust
    // Toegang enkel via Private Endpoint PE: 10.20.3.4 poort 1433
    publicDataEndpointEnabled: false

    // TLS 1.2 minimum — NIS2 Art. 21(2)(h) — cryptografie in transit
    minimalTlsVersion: '1.2'

    // Verbindingstype: Redirect (lagere latency dan Proxy)
    // Vereist NSG-regels voor poorten 11000-11999
    proxyOverride: 'Redirect'

    // ── Opslag ────────────────────────────────────────────────
    storageSizeInGB: storageSizeInGB

    // Zone-redundante backup storage — ALZ vereiste
    requestedBackupStorageRedundancy: 'Zone'

    // ── Collatie & tijdzone ───────────────────────────────────
    collation:  'SQL_Latin1_General_CP1_CI_AS'
    timezoneId: 'Central European Standard Time'   // België = CET/CEST

    // ── Maintenance window ────────────────────────────────────
    // Zaterdag 22:00 — minimale impact op kantooruren
    maintenanceConfigurationId: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Maintenance/publicMaintenanceConfigurations/SQL_${location}_MI_1'
  }
}

// ── Transparent Data Encryption (TDE) ────────────────────────────
// Versleutelt alle data-at-rest: databestanden, logbestanden en backups
// Service-managed key: Azure beheert de sleutel automatisch
// Alternatief: customer-managed key via kv-contoso-platform (meer controle)
// NIS2 Art. 21(2)(h) — cryptografie en versleuteling
resource tde 'Microsoft.Sql/managedInstances/encryptionProtector@2023-02-01-preview' = {
  parent: sqlManagedInstance
  name:   'current'
  properties: {
    // ServiceManaged = Azure-beheerde sleutel (eenvoudigst)
    // AzureKeyVault  = customer-managed key via Key Vault (meer controle)
    serverKeyType: 'ServiceManaged'

    // TDE automatisch ingeschakeld op SQL MI — deze resource bevestigt dat
    // autoRotationEnabled geldt enkel bij AzureKeyVault serverKeyType
  }
}

// ── Vulnerability Assessment ──────────────────────────────────────
// Wekelijkse scan op beveiligingsproblemen in de SQL MI configuratie
// Vereist: Defender for SQL MI plan actief (zie Defender for Cloud)
// Vereist: Storage Account URI voor opslaan van rapporten
// NIS2 Art. 21(2)(b) — monitoring en detectie
// NIS2 Art. 21(2)(a) — risicoanalyse
resource securityAssessmentPolicy 'Microsoft.Sql/managedInstances/securityAlertPolicies@2023-02-01-preview' = {
  parent: sqlManagedInstance
  name:   'Default'
  properties: {
    // Schakel Advanced Threat Protection in — detecteert SQL injection,
    // bruteforce aanvallen en anomale toegangspatronen
    state: 'Enabled'
    // Email naar DBA en security team bij alert
    emailAccountAdmins: true
  }
}

resource vulnerabilityAssessment 'Microsoft.Sql/managedInstances/vulnerabilityAssessments@2023-02-01-preview' = if (!empty(vulnerabilityAssessmentStorageUri)) {
  parent: sqlManagedInstance
  name:   'default'
  properties: {
    storageContainerPath: '${vulnerabilityAssessmentStorageUri}vulnerability-assessment/'

    recurringScans: {
      // Wekelijkse automatische scan
      isEnabled:           true
      emailSubscriptionAdmins: true
      emails: [
        'bjorn.pacquet@contoso.be'
        'dba@contoso.be'
      ]
    }
  }
  // Vulnerability assessment hangt af van security alert policy
  dependsOn: [securityAssessmentPolicy]
}

// ── Diagnostics → Log Analytics ──────────────────────────────────
// SQL MI audit logs — NIS2 Art. 21(2)(b) monitoring en detectie
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name:  '${serverName}-diagnostics'
  scope: sqlManagedInstance
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        // Alle logins, role changes, schema changes — security audit trail
        category: 'SQLSecurityAuditEvents'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        // Query performance en anomalieën
        category: 'QueryStoreRuntimeStatistics'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        category: 'QueryStoreWaitStatistics'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        // Foutmeldingen en connectieproblemen
        category: 'Errors'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
    metrics: [
      {
        category: 'Basic'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────
@description('Naam van de SQL Managed Instance')
output serverName string = sqlManagedInstance.name

@description('Resource ID van de SQL Managed Instance')
output serverId string = sqlManagedInstance.id

@description('Fully Qualified Domain Name — gebruikt in connection strings')
output fqdn string = sqlManagedInstance.properties.fullyQualifiedDomainName

@description('Principal ID van de system-assigned Managed Identity — voor RBAC')
output managedIdentityPrincipalId string = sqlManagedInstance.identity.principalId
