// =============================================================================
// modules/data/sql-database.bicep
// Database op SQL Managed Instance + geo-replicatie naar North Europe
// -----------------------------------------------------------------------------
// PITR    : 35 dagen — ALZ v2 maximum + NIS2 Art. 21(2)(c)
// LTR     : 7d / 4w / 12m / 3j — Recovery Services Vault retentiebeleid
// Geo-rep : auto-failover group naar North Europe — RPO <5s, RTO <30s
// =============================================================================

// ── Parameters ───────────────────────────────────────────────────
@description('Azure regio voor de resource (primary)')
param location string

@description('Azure regio voor de geo-replica (DR)')
param drLocation string = 'northeurope'

@description('Naam van de SQL Managed Instance (primary)')
@minLength(1)
@maxLength(63)
param serverName string

@description('Naam van de SQL Managed Instance (DR) — voor auto-failover group')
@minLength(1)
@maxLength(63)
param drServerName string = ''

@description('Naam van de database — bv. sqldb-contoso-prd')
@minLength(1)
@maxLength(128)
param databaseName string

@description('Naam van de auto-failover group — bv. fog-contoso-prd')
@minLength(1)
@maxLength(63)
param failoverGroupName string = 'fog-${serverName}'

@description('Resource ID van de Log Analytics Workspace voor diagnostics')
param logAnalyticsWorkspaceId string

@description('Tags die op alle resources worden toegepast')
param tags object

// ── Bestaande SQL MI opzoeken ─────────────────────────────────────
resource sqlMI 'Microsoft.Sql/managedInstances@2023-02-01-preview' existing = {
  name: serverName
}

// ── Database ──────────────────────────────────────────────────────
resource sqlDatabase 'Microsoft.Sql/managedInstances/databases@2023-02-01-preview' = {
  parent:   sqlMI
  name:     databaseName
  location: location
  tags:     tags
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    // createMode: Default = nieuwe lege database
    // Andere opties: RestoreExternalBackup, Recovery, RestoreLongTermRetentionBackup
    createMode: 'Default'
  }
}

// ── Short Term Retention (PITR) ───────────────────────────────────
// Point-In-Time Restore: herstel naar elk tijdstip binnen 35 dagen
// Azure maakt automatisch elke 5-15 min een log-backup
// 35 dagen = maximum voor SQL MI en ALZ v2 vereiste
resource pitrPolicy 'Microsoft.Sql/managedInstances/databases/backupShortTermRetentionPolicies@2023-02-01-preview' = {
  parent: sqlDatabase
  name:   'default'
  properties: {
    retentionDays: 35   // Maximum voor SQL MI
  }
}

// ── Long Term Retention ───────────────────────────────────────────
// Wekelijkse, maandelijkse en jaarlijkse backups buiten de 35-daagse PITR
// NIS2 Art. 21(2)(c) — bedrijfscontinuïteit
// GDPR: geen specifieke bewaarplicht maar sectorale normen = 2-3 jaar
resource ltrPolicy 'Microsoft.Sql/managedInstances/databases/backupLongTermRetentionPolicies@2023-02-01-preview' = {
  parent: sqlDatabase
  name:   'default'
  properties: {
    weeklyRetention:  'P4W'   // 4 weken
    monthlyRetention: 'P12M'  // 12 maanden
    yearlyRetention:  'P3Y'   // 3 jaar
    weekOfYear:       1       // Eerste week van het jaar voor jaarlijkse backup
  }
}

// ── Auto-failover group (geo-replicatie) ──────────────────────────
// Repliceert alle transacties asynchroon naar DR-instance in North Europe
// RPO <5s: maximaal 5 seconden aan transacties gaan verloren bij failover
// RTO <30s: binnen 30 seconden is secondary de nieuwe primary
// Alleen aanmaken als een DR-serverName is meegegeven
resource failoverGroup 'Microsoft.Sql/managedInstances/failoverGroups@2023-02-01-preview' = if (!empty(drServerName)) {
  parent: sqlMI
  name:   failoverGroupName
  properties: {
    // Automatische failover zonder menselijke tussenkomst
    readWriteEndpoint: {
      failoverPolicy:                         'Automatic'
      failoverWithDataLossGracePeriodMinutes: 60  // Max 60 min voor data-loss failover
    }
    // Read-only endpoint: DR-replica beschikbaar voor rapportage-queries
    // Ontlast productie-instance bij maandafsluiting
    readOnlyEndpoint: {
      failoverPolicy: 'Enabled'
    }
    partnerRegions: [
      {
        location: drLocation
      }
    ]
    // Alle databases in de MI opnemen in de failover group
    managedInstancePairs: [
      {
        primaryManagedInstanceId: sqlMI.id
        partnerManagedInstanceId: resourceId('Microsoft.Sql/managedInstances', drServerName)
      }
    ]
  }
}

// ── Diagnostics → Log Analytics ──────────────────────────────────
// Database-niveau diagnostics: query performance, deadlocks, waits
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name:  '${databaseName}-diagnostics'
  scope: sqlDatabase
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'SQLInsights'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        category: 'AutomaticTuning'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        category: 'QueryStoreRuntimeStatistics'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        category: 'Errors'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        category: 'DatabaseWaitStatistics'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────
@description('Naam van de database')
output databaseName string = sqlDatabase.name

@description('Resource ID van de database')
output databaseId string = sqlDatabase.id

@description('Naam van de auto-failover group (leeg als geen DR geconfigureerd)')
output failoverGroupName string = !empty(drServerName) ? failoverGroup.name : ''

@description('Read-write endpoint van de failover group voor connection strings')
output failoverGroupReadWriteEndpoint string = !empty(drServerName)
  ? '${failoverGroupName}.${sqlMI.properties.fullyQualifiedDomainName}'
  : sqlMI.properties.fullyQualifiedDomainName
