param location string
param prefix string
param subnetId string
param spokeVnetId string
param keyVaultId string
param storageAccountId string
param webAppId string = ''
param tags object

resource dnsKv 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource dnsBlob 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}

resource dnsWeb 'Microsoft.Network/privateDnsZones@2020-06-01' = if (!empty(webAppId)) {
  name: 'privatelink.azurewebsites.net'
  location: 'global'
  tags: tags
}

resource kvLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsKv
  name: 'link-${prefix}-spoke-kv'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

resource blobLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsBlob
  name: 'link-${prefix}-spoke-blob'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

resource webLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = if (!empty(webAppId)) {
  parent: dnsWeb
  name: 'link-${prefix}-spoke-web'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: { id: spokeVnetId }
  }
}

resource peKv 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: 'pe-${prefix}-kv'
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: 'kv-connection'
        properties: {
          privateLinkServiceId: keyVaultId
          groupIds: ['vault']
        }
      }
    ]
  }
}

resource peKvDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: peKv
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'kv'
        properties: { privateDnsZoneId: dnsKv.id }
      }
    ]
  }
}

resource peBlob 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: 'pe-${prefix}-blob'
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: 'blob-connection'
        properties: {
          privateLinkServiceId: storageAccountId
          groupIds: ['blob']
        }
      }
    ]
  }
}

resource peBlobDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: peBlob
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'blob'
        properties: { privateDnsZoneId: dnsBlob.id }
      }
    ]
  }
}

resource peWeb 'Microsoft.Network/privateEndpoints@2023-09-01' = if (!empty(webAppId)) {
  name: 'pe-${prefix}-web'
  location: location
  tags: tags
  properties: {
    subnet: { id: subnetId }
    privateLinkServiceConnections: [
      {
        name: 'web-connection'
        properties: {
          privateLinkServiceId: webAppId
          groupIds: ['sites']
        }
      }
    ]
  }
}

resource peWebDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (!empty(webAppId)) {
  parent: peWeb
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'web'
        properties: { privateDnsZoneId: dnsWeb.id }
      }
    ]
  }
}

output keyVaultPrivateEndpointId string = peKv.id
output storagePrivateEndpointId string = peBlob.id
