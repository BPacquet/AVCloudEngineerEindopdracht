// modules/compute/function-app.bicep
// Azure Functions — Consumption plan met VNet Integration
// Consumers: Scheduler | Processor (Service Bus) | Reporter (SQL MI)
// Managed Identity: system-assigned — Key Vault + Service Bus + Storage

param location          string
param functionAppName   string
param appServicePlanId  string
param storageAccountName string
param keyVaultUri       string
param vnetSubnetId      string
param managedIdentityId string
param tags              object

resource functionApp 'Microsoft.Web/sites@2023-01-01' = {
  name:     functionAppName
  location: location
  tags:     tags
  kind:     'functionapp'
  identity: {
    type: 'SystemAssigned'   // Managed Identity — geen SAS-tokens of passwords
  }
  properties: {
    serverFarmId: appServicePlanId
    httpsOnly:    true
    siteConfig: {
      ftpsState:     'Disabled'
      minTlsVersion: '1.2'

      appSettings: [
        {
          // Storage via Managed Identity — geen access key
          // Syntax: accountName + credential=managedidentity
          name:  'AzureWebJobsStorage__accountName'
          value: storageAccountName
        }
        {
          name:  'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          // Service Bus via Managed Identity — geen connection string
          // RBAC vereist: Azure Service Bus Data Receiver op sb-contoso-prd
          name:  'ServiceBusConnection__fullyQualifiedNamespace'
          value: 'sb-contoso-prd.servicebus.windows.net'
        }
        {
          name:  'ServiceBusConnection__credential'
          value: 'managedidentity'
        }
        {
          name:  'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name:  'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name:  'KeyVaultUri'
          value: keyVaultUri
        }
        {
          // SQL MI connection string — Managed Identity auth, geen wachtwoord
          name:  'SQL_CONNECTION_STRING'
          value: 'Server=10.20.3.4,1433;Database=ContosoDB;Authentication=Active Directory Managed Identity;Encrypt=True;'
        }
      ]
    }

    // VNet Integration — outbound via snet-spoke-func
    virtualNetworkSubnetId: vnetSubnetId
  }
}

// ── Outputs ───────────────────────────────────────────────────────
output functionAppName    string = functionApp.name
output functionAppId      string = functionApp.id
output managedIdentityPrincipalId string = functionApp.identity.principalId
