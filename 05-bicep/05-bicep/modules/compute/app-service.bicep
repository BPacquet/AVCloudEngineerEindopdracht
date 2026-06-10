// =============================================================================
// modules/compute/app-service.bicep
// App Service — web-contoso-prd | ASP.NET WebForms .NET Framework 4.8
// -----------------------------------------------------------------------------
// Managed Identity : system-assigned — passwordless KV + SQL MI toegang
// VNet Integration : outbound via snet-spoke-web, all traffic via UDR
// Health check     : /health — App Service health monitoring
// KV references    : SecretUri syntax — versie-onafhankelijk
// Slots            : staging slot voor zero-downtime deployment (prd)
// Diagnostics      : Log Analytics — HTTP, console, app en audit logs
// =============================================================================

// ── Parameters ───────────────────────────────────────────────────
@description('Azure regio voor de resource')
param location string

@description('Naam van de App Service — bv. web-contoso-prd')
@minLength(2)
@maxLength(60)
param appName string

@description('Resource ID van het App Service Plan')
param appServicePlanId string

@description('URI van de Key Vault — bv. https://kv-contoso-prd.vault.azure.net/')
param keyVaultUri string

@description('Resource ID van het VNet Integration subnet (snet-spoke-web)')
param vnetSubnetId string

@description('Resource ID van de Log Analytics Workspace voor diagnostics')
param logAnalyticsWorkspaceId string

@description('Health check pad — endpoint dat 200 OK retourneert')
param healthCheckPath string = '/health'

@description('True = prd (always on, staging slot) | False = dev/tst')
param isPrd bool = true

@description('Tags die op alle resources worden toegepast')
param tags object

// ── Variables ────────────────────────────────────────────────────
// SQL MI connection string — Managed Identity auth, geen wachtwoord
// Private Endpoint 10.20.3.4 | poort 1433
var sqlConnectionString = 'Server=10.20.3.4,1433;Database=ContosoDB;Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;'

// Key Vault reference — SecretUri syntax (versie-onafhankelijk, aanbevolen)
// Alternatief: VaultName/SecretName syntax (pint altijd naar laatste versie)
// SecretUri zonder versie = altijd de laatste versie van het secret
var kvRef = {
  sapKey:  '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/sap-integration-key/)'
  sbConn:  '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/servicebus-connection/)'
  stKey:   '@Microsoft.KeyVault(SecretUri=${keyVaultUri}secrets/storage-account-key/)'
}

// ── App Service ───────────────────────────────────────────────────
resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name:     appName
  location: location
  tags:     tags
  kind:     'app'   // Windows web app
  identity: {
    // System-assigned: Azure beheert token-rotatie automatisch
    // Principal ID wordt gebruikt voor RBAC toewijzingen (KV, SQL MI)
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId

    // HTTPS only — Azure Policy Deny als false
    // NIS2 Art. 21(2)(h) — versleuteling in transit
    httpsOnly: true

    siteConfig: {
      // .NET Framework 4.8 — verplicht voor ASP.NET WebForms
      windowsFxVersion:    'DOTNET|4.8'
      netFrameworkVersion: 'v4.8'

      // Beveiliging
      ftpsState:     'Disabled'   // Geen FTP — enkel pipeline deployment
      minTlsVersion: '1.2'        // TLS 1.2 minimum — NIS2 Art. 21(2)(h)
      http20Enabled: true

      // Always On: voorkomt cold starts op P2v3 prd
      // Uitschakelen op B2 dev (Basic tier ondersteunt Always On niet)
      alwaysOn: isPrd

      // Health check — App Service bewaakt dit endpoint elke minuut
      // Bij 2 opeenvolgende fouten: instantie uit rotation, nieuwe gestart
      // Endpoint moet HTTP 200 retourneren bij gezonde staat
      healthCheckPath: healthCheckPath

      // VNet Integration: al het outbound verkeer via snet-spoke-web → UDR → Firewall
      vnetRouteAllEnabled: true

      // Connection string — Managed Identity, geen wachtwoord
      connectionStrings: [
        {
          name:             'DefaultConnection'
          connectionString: sqlConnectionString
          type:             'SQLServer'
        }
      ]

      // App settings — secrets via Key Vault SecretUri reference
      // Azure vervangt @Microsoft.KeyVault(...) automatisch met de geheime waarde
      // Vereiste RBAC: App Service Managed Identity heeft 'Key Vault Secrets User'
      appSettings: [
        {
          // SAP ERP REST/SOAP API key
          name:  'SAP_API_KEY'
          value: kvRef.sapKey
        }
        {
          // Service Bus connection string
          name:  'SERVICEBUS_CONNECTION'
          value: kvRef.sbConn
        }
        {
          // Storage Account key — voor Functions state (indien gecombineerd)
          name:  'STORAGE_ACCOUNT_KEY'
          value: kvRef.stKey
        }
        {
          // Key Vault URI — voor DefaultAzureCredential in C# code
          name:  'KeyVaultUri'
          value: keyVaultUri
        }
        {
          // Run from package — deployment via ZIP deploy, geen schrijven naar disk
          name:  'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name:  'ASPNETCORE_ENVIRONMENT'
          value: isPrd ? 'Production' : 'Development'
        }
        {
          // Health check endpoint pad — ook beschikbaar als app setting
          name:  'HEALTH_CHECK_PATH'
          value: healthCheckPath
        }
      ]
    }

    // VNet Integration subnet (snet-spoke-web)
    // Delegatie Microsoft.Web/serverFarms vereist op het subnet
    virtualNetworkSubnetId: vnetSubnetId
  }
}

// ── Auto-scale profiel ────────────────────────────────────────────
// Schaal: 2 (minimum, HA) → 6 (maximum, 120 gelijktijdige gebruikers)
// Alleen in prd — dev heeft vaste capaciteit
resource autoScale 'Microsoft.Insights/autoscalesettings@2022-10-01' = if (isPrd) {
  name:     '${appName}-autoscale'
  location: location
  tags:     tags
  properties: {
    enabled:                true
    targetResourceId:       appServicePlanId
    targetResourceLocation: location
    profiles: [
      {
        name: 'default-profile'
        capacity: {
          minimum: '2'   // Min 2 voor zone-redundante HA
          maximum: '6'   // Max 6 bij piekload (120 gelijktijdige gebruikers)
          default: '2'
        }
        rules: [
          {
            // Scale-out: CPU > 70% gedurende 5 min → +1 instantie
            metricTrigger: {
              metricName:        'CpuPercentage'
              metricResourceUri: appServicePlanId
              timeGrain:         'PT1M'
              statistic:         'Average'
              timeWindow:        'PT5M'
              timeAggregation:   'Average'
              operator:          'GreaterThan'
              threshold:         70
            }
            scaleAction: {
              direction: 'Increase'
              type:      'ChangeCount'
              value:     '1'
              cooldown:  'PT5M'
            }
          }
          {
            // Scale-in: CPU < 30% gedurende 10 min → -1 instantie
            metricTrigger: {
              metricName:        'CpuPercentage'
              metricResourceUri: appServicePlanId
              timeGrain:         'PT1M'
              statistic:         'Average'
              timeWindow:        'PT10M'
              timeAggregation:   'Average'
              operator:          'LessThan'
              threshold:         30
            }
            scaleAction: {
              direction: 'Decrease'
              type:      'ChangeCount'
              value:     '1'
              cooldown:  'PT10M'
            }
          }
        ]
      }
    ]
  }
}

// ── Staging slot (alleen prd) ─────────────────────────────────────
// Zero-downtime deployments: deploy naar staging, swap naar production
// Staging slot heeft eigen Managed Identity voor Key Vault toegang
resource stagingSlot 'Microsoft.Web/sites/slots@2023-01-01' = if (isPrd) {
  parent:   webApp
  name:     'staging'
  location: location
  tags:     union(tags, { SlotPurpose: 'deployment-staging' })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly:    true
    siteConfig: {
      windowsFxVersion:    'DOTNET|4.8'
      netFrameworkVersion: 'v4.8'
      ftpsState:           'Disabled'
      minTlsVersion:       '1.2'
      alwaysOn:            true
      healthCheckPath:     healthCheckPath
      vnetRouteAllEnabled: true
      connectionStrings: [
        {
          name:             'DefaultConnection'
          connectionString: sqlConnectionString
          type:             'SQLServer'
        }
      ]
      appSettings: [
        { name: 'SAP_API_KEY',             value: kvRef.sapKey  }
        { name: 'SERVICEBUS_CONNECTION',   value: kvRef.sbConn  }
        { name: 'STORAGE_ACCOUNT_KEY',     value: kvRef.stKey   }
        { name: 'KeyVaultUri',             value: keyVaultUri    }
        { name: 'WEBSITE_RUN_FROM_PACKAGE', value: '1'          }
        { name: 'ASPNETCORE_ENVIRONMENT',  value: 'Staging'     }
        { name: 'HEALTH_CHECK_PATH',       value: healthCheckPath }
      ]
    }
    virtualNetworkSubnetId: vnetSubnetId
  }
}

// ── Diagnostics → Log Analytics ──────────────────────────────────
// NIS2 Art. 21(2)(b) — monitoring en detectie
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name:  '${appName}-diagnostics'
  scope: webApp
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        category: 'AppServiceHTTPLogs'      // Alle HTTP requests en responses
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        category: 'AppServiceConsoleLogs'   // Console.WriteLine en stdout
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        category: 'AppServiceAppLogs'       // ILogger / log4net / NLog output
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        category: 'AppServiceAuditLogs'     // Authenticatie en authorisatie events
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
      {
        category: 'AppServiceIPSecAuditLogs' // IP restriction audit
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled:  true
        retentionPolicy: { enabled: false, days: 0 }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────
@description('Naam van de App Service')
output appName string = webApp.name

@description('Resource ID van de App Service')
output appId string = webApp.id

@description('Standaard hostname — bv. web-contoso-prd.azurewebsites.net')
output defaultHostname string = webApp.properties.defaultHostName

@description('Principal ID van de system-assigned Managed Identity — voor RBAC toewijzingen aan Key Vault en SQL MI')
output managedIdentityPrincipalId string = webApp.identity.principalId

@description('Resource ID van de staging slot (leeg als isPrd = false)')
output stagingSlotId string = isPrd ? stagingSlot.id : ''
