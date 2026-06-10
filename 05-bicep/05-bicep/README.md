# 05-bicep — Contoso Manufacturing IaC

> **Tooling:** Azure Bicep | **Scope:** Subscription
> **Architectuur:** Hub-Spoke ALZ Corp | West Europe (prd) | North Europe (dr)

## Mappenstructuur

```
05-bicep/
├── main.bicep                        Orchestrator — roept alle modules aan
├── main.bicepparam                   Parameters productie (prd)
├── main.dev.bicepparam               Parameters development (dev)
└── modules/
    ├── network/
    │   ├── hub-vnet.bicep            Hub VNet 10.0.0.0/16 + 6 subnetten
    │   ├── spoke-vnet.bicep          Spoke VNet 10.20.0.0/16 + 6 subnetten
    │   ├── nsg.bicep                 NSG-regels (appgw, web, data)
    │   └── private-endpoint.bicep   PE Key Vault + Blob + Private DNS Zones
    ├── compute/
    │   ├── app-service-plan.bicep    App Service Plan P2v3 (prd) / B2 (dev)
    │   ├── app-service.bicep         web-contoso-prd + auto-scale + Managed Identity
    │   └── function-app.bicep        fn-contoso-prd-001 + Service Bus MI auth
    ├── data/
    │   ├── sql-server.bicep          SQL MI GP 8vCore + AHB + AAD auth
    │   ├── sql-database.bicep        ContosoDB + PITR 35d + LTR 7d/4w/12m
    │   └── storage-account.bicep     stcontoso{env}001 ZRS + lifecycle policy
    └── security/
        ├── key-vault.bicep           kv-contoso-{env} + RBAC + PE + diagnostics
        └── managed-identity.bicep    mi-contoso-{env}-app (user-assigned)
```

## Deployment

### Vereisten

```bash
az --version          # Azure CLI >= 2.50
az bicep version      # Bicep >= 0.24
az login
az account set --subscription "Contoso-Prod"
```

### Productie deployen

```bash
# Stap 1: SQL admin wachtwoord instellen als omgevingsvariabele
export SQL_ADMIN_PASSWORD="<sterk-wachtwoord>"   # Linux/Mac
$env:SQL_ADMIN_PASSWORD = "<sterk-wachtwoord>"    # PowerShell

# Stap 2: Wat-als validatie (dry-run)
az deployment sub what-if \
  --location westeurope \
  --template-file main.bicep \
  --parameters main.bicepparam

# Stap 3: Effectieve deployment
az deployment sub create \
  --name "contoso-prd-$(date +%Y%m%d-%H%M)" \
  --location westeurope \
  --template-file main.bicep \
  --parameters main.bicepparam
```

### Development deployen

```bash
export SQL_ADMIN_PASSWORD_DEV="<dev-wachtwoord>"

az deployment sub create \
  --name "contoso-dev-$(date +%Y%m%d-%H%M)" \
  --location westeurope \
  --template-file main.bicep \
  --parameters main.dev.bicepparam
```

## Architectuurbeslissingen

| Beslissing | Keuze | Reden |
|---|---|---|
| App Service SKU prd | P2v3 Windows | .NET Framework 4.8 vereist Windows; P2v3 min voor auto-scale + staging slot |
| App Service SKU dev | B2 | Dev/Test pricing — geen HA nodig in dev |
| SQL MI | GP 8 vCore | 99% SQL Server-compatibiliteit; benchmark 6-8 vCore bij maandafsluiting |
| Storage replicatie | ZRS | ALZ-vereiste — zone-redundant in West Europe |
| Key Vault RBAC | `enableRbacAuthorization: true` | RBAC ondersteunt PIM; Access Policies niet |
| Managed Identity | SystemAssigned per resource | Lifecycle gekoppeld aan resource — eenvoudiger beheer |
| AHB SQL MI | `licenseType: BasePrice` | BasePrice = AHB ingeschakeld; ~40% korting met SQL Enterprise SA |
| Publieke SQL MI | `publicDataEndpointEnabled: false` | Azure Policy Deny — NIS2 Art. 21(2)(a) |
| Storage publieke toegang | `publicNetworkAccess: Disabled` | Enkel via Private Endpoint |

## Vereiste RBAC voor deployment service principal

De DevOps service principal die de pipeline uitvoert heeft de volgende rechten nodig:

```bash
# Contributor op alle resource groups
az role assignment create \
  --assignee "<sp-object-id>" \
  --role "Contributor" \
  --scope "/subscriptions/<prod-sub-id>"

# User Access Administrator voor RBAC-toewijzingen in Bicep
az role assignment create \
  --assignee "<sp-object-id>" \
  --role "User Access Administrator" \
  --scope "/subscriptions/<prod-sub-id>"
```
