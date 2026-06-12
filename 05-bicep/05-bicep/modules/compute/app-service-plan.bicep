param location string
param planName string
@allowed(['P2v3','B2'])
param skuName string
param tags object

var skuConfig = skuName == 'P2v3' ? {
  tier: 'PremiumV3'
  capacity: 2
  zoneRedundant: false
} : {
  tier: 'Basic'
  capacity: 1
  zoneRedundant: false
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: planName
  location: location
  tags: tags
  kind: 'app'
  sku: {
    name: skuName
    tier: skuConfig.tier
    capacity: skuConfig.capacity
  }
  properties: {
    reserved: false
    zoneRedundant: skuConfig.zoneRedundant
  }
}

output planId string = plan.id
output planName string = plan.name
