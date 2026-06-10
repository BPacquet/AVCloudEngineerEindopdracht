// =============================================================================
// modules/compute/app-service-plan.bicep
// App Service Plan — Windows (vereist voor ASP.NET WebForms .NET Framework 4.8)
// -----------------------------------------------------------------------------
// SKU prd : P2v3 — 2 vCPU, 8 GB RAM, auto-scale, staging slots, zone-redundant
// SKU dev : B2   — 2 vCPU, 3.5 GB RAM, geen auto-scale (Dev/Test pricing)
// AHB     : Windows Server Datacenter SA — ~18% korting op licentiedeel
// =============================================================================

// ── Parameters ───────────────────────────────────────────────────
@description('Azure regio voor de resource')
param location string

@description('Naam van het App Service Plan — bv. asp-contoso-prd')
@minLength(1)
@maxLength(40)
param planName string

@description('SKU van het plan: P2v3 (productie) of B2 (development)')
@allowed(['P2v3', 'B2'])
param sku string

@description('Resource ID van de Log Analytics Workspace voor diagnostics')
param logAnalyticsWorkspaceId string

@description('Tags die op alle resources worden toegepast')
param tags object

// ── Variables ────────────────────────────────────────────────────
// SKU-configuratie op basis van de gekozen tier
// P2v3: PremiumV3, zone-redundant, min 2 instanties voor HA
// B2  : Basic, geen zone-redundantie, 1 instantie (dev/tst)
var skuConfig = sku == 'P2v3' ? {
  name:          'P2v3'
  tier:          'PremiumV3'
  size:          'P2v3'
  family:        'Pv3'
  capacity:      2        // Min 2 voor HA — auto-scale regelt de rest
  zoneRedundant: true
} : {
  name:          'B2'
  tier:          'Basic'
  size:          'B2'
  family:        'B'
  capacity:      1
  zoneRedundant: false
}

// ── App Service Plan ──────────────────────────────────────────────
resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name:     planName
  location: location
  tags:     tags
  kind:     'windows'   // Verplicht voor ASP.NET WebForms op .NET Framework 4.8
  sku: {
    name:     skuConfig.name
    tier:     skuConfig.tier
    size:     skuConfig.size
    family:   skuConfig.family
    capacity: skuConfig.capacity
  }
  properties: {
    reserved:      false               // false = Windows, true = Linux
    zoneRedundant: skuConfig.zoneRedundant
    // targetWorkerCount en targetWorkerSizeId worden beheerd via auto-scale
  }
}

// ── Diagnostics → Log Analytics ──────────────────────────────────
// App Service Plan metrics: CpuPercentage, MemoryPercentage, DiskQueueLength
// Gebruikt door auto-scale triggers en Azure Monitor alerts
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name:  '${planName}-diagnostics'
  scope: appServicePlan
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    metrics: [
      {
        category: 'AllMetrics'
        enabled:  true
        retentionPolicy: {
          enabled: false
          days:    0   // Retentie beheerd door Log Analytics workspace (90d/2j)
        }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────
@description('Resource ID van het App Service Plan — gebruikt door app-service.bicep en function-app.bicep')
output planId string = appServicePlan.id

@description('Naam van het App Service Plan')
output planName string = appServicePlan.name

@description('SKU-naam van het plan — gebruikt voor conditionals in modules')
output planSku string = appServicePlan.sku.name
