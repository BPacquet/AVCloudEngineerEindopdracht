// =============================================================================
// modules/network/private-endpoint.bicep
// Private Endpoints voor alle PaaS-services in snet-spoke-data (10.20.3.0/24)
// -----------------------------------------------------------------------------
// PE-adressen:  SQL MI       → 10.20.3.4
//               Blob Storage → 10.20.3.5
//               Key Vault    → 10.20.3.6
//               Service Bus  → 10.20.3.7
//               App Service  → 10.20.3.8
// DNS: Private DNS Zones worden aangemaakt en gelinkt aan Hub VNet
// =============================================================================

// ── Parameters ───────────────────────────────────────────────────
@description('Azure regio voor de resource')
param location string

@description('Resource ID van het PE-subnet (snet-spoke-data)')
param subnetId string

@description('Resource ID van de Key Vault')
param keyVaultId string

@description('Resource ID van het Storage Account')
param storageAccountId string

@description('Resource ID van de Service Bus namespace')
param serviceBusId string = ''

@description('Resource ID van de App Service')
param appServiceId string = ''

@description('Resource ID van het Hub VNet — voor DNS Zone koppeling')
param hubVnetId string

@description('Naamprefix voor alle Private Endpoints — bv. contoso-prd')
@minLength(1)
@maxLength(40)
param prefix string

@description('Tags die op alle resources worden toegepast')
param tags object

// ── Variables ────────────────────────────────────────────────────
// Private DNS Zone namen per resource type (Microsoft standaard)
var dnsZones = {
  keyVault:    'privatelink.vaultcore.azure.net'
  blob:        'privatelink.blob.core.windows.net'
  file:        'privatelink.file.core.windows.net'
  serviceBus:  'privatelink.servicebus.windows.net'
  appService:  'privatelink.azurewebsites.net'
}

// ── Hulpfunctie: DNS Zone aanmaken en linken aan Hub VNet ─────────
// Key Vault DNS Zone
resource dnsZoneKv 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name:     dnsZones.keyVault
  location: 'global'
  tags:     tags
}

resource dnsZoneKvLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent:   dnsZoneKv
  name:     'link-${split(hubVnetId, '/')[8]}'
  location: 'global'
  properties: {
    virtualNetwork:      { id: hubVnetId }
    registrationEnabled: false  // Geen auto-registratie — alleen PE-records
  }
}

// Blob Storage DNS Zone
resource dnsZoneBlob 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name:     dnsZones.blob
  location: 'global'
  tags:     tags
}

resource dnsZoneBlobLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent:   dnsZoneBlob
  name:     'link-${split(hubVnetId, '/')[8]}'
  location: 'global'
  properties: {
    virtualNetwork:      { id: hubVnetId }
    registrationEnabled: false
  }
}

// Service Bus DNS Zone
resource dnsZoneSb 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!empty(serviceBusId)) {
  name:     dnsZones.serviceBus
  location: 'global'
  tags:     tags
}

resource dnsZoneSbLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!empty(serviceBusId)) {
  parent:   dnsZoneSb
  name:     'link-${split(hubVnetId, '/')[8]}'
  location: 'global'
  properties: {
    virtualNetwork:      { id: hubVnetId }
    registrationEnabled: false
  }
}

// App Service DNS Zone
resource dnsZoneApp 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!empty(appServiceId)) {
  name:     dnsZones.appService
  location: 'global'
  tags:     tags
}

resource dnsZoneAppLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!empty(appServiceId)) {
  parent:   dnsZoneApp
  name:     'link-${split(hubVnetId, '/')[8]}'
  location: 'global'
  properties: {
    virtualNetwork:      { id: hubVnetId }
    registrationEnabled: false
  }
}

// ── PE: Key Vault (10.20.3.6) ─────────────────────────────────────
resource peKeyVault 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name:     'pe-kv-${prefix}'
  location: location
  tags:     tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: 'conn-kv-${prefix}'
        properties: {
          privateLinkServiceId: keyVaultId
          groupIds:             ['vault']
        }
      }
    ]
  }
}

resource peKvDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: peKeyVault
  name:   'zonegroup-kv'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'kv-zone'
        properties: { privateDnsZoneId: dnsZoneKv.id }
      }
    ]
  }
}

// ── PE: Blob Storage (10.20.3.5) ──────────────────────────────────
resource peBlob 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name:     'pe-blob-${prefix}'
  location: location
  tags:     tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: 'conn-blob-${prefix}'
        properties: {
          privateLinkServiceId: storageAccountId
          groupIds:             ['blob']
        }
      }
    ]
  }
}

resource peBlobDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: peBlob
  name:   'zonegroup-blob'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob-zone'
        properties: { privateDnsZoneId: dnsZoneBlob.id }
      }
    ]
  }
}

// ── PE: Service Bus (10.20.3.7) — optioneel ───────────────────────
resource peServiceBus 'Microsoft.Network/privateEndpoints@2023-09-01' = if (!empty(serviceBusId)) {
  name:     'pe-sb-${prefix}'
  location: location
  tags:     tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: 'conn-sb-${prefix}'
        properties: {
          privateLinkServiceId: serviceBusId
          groupIds:             ['namespace']
        }
      }
    ]
  }
}

resource peSbDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (!empty(serviceBusId)) {
  parent: peServiceBus
  name:   'zonegroup-sb'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'sb-zone'
        properties: { privateDnsZoneId: dnsZoneSb.id }
      }
    ]
  }
}

// ── PE: App Service (10.20.3.8) — optioneel ───────────────────────
// Voor interne app-to-app communicatie zonder via AGW te gaan
resource peAppService 'Microsoft.Network/privateEndpoints@2023-09-01' = if (!empty(appServiceId)) {
  name:     'pe-app-${prefix}'
  location: location
  tags:     tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: 'conn-app-${prefix}'
        properties: {
          privateLinkServiceId: appServiceId
          groupIds:             ['sites']
        }
      }
    ]
  }
}

resource peAppDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (!empty(appServiceId)) {
  parent: peAppService
  name:   'zonegroup-app'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'app-zone'
        properties: { privateDnsZoneId: dnsZoneApp.id }
      }
    ]
  }
}

// ── Outputs ───────────────────────────────────────────────────────
@description('Resource ID van de Key Vault Private Endpoint')
output peKeyVaultId string = peKeyVault.id

@description('Resource ID van de Blob Storage Private Endpoint')
output peBlobId string = peBlob.id

@description('Resource ID van de Service Bus Private Endpoint (leeg als niet geconfigureerd)')
output peServiceBusId string = !empty(serviceBusId) ? peServiceBus.id : ''

@description('Resource ID van de App Service Private Endpoint (leeg als niet geconfigureerd)')
output peAppServiceId string = !empty(appServiceId) ? peAppService.id : ''

@description('Resource ID van de Key Vault Private DNS Zone')
output dnsZoneKvId string = dnsZoneKv.id

@description('Resource ID van de Blob Storage Private DNS Zone')
output dnsZoneBlobId string = dnsZoneBlob.id
