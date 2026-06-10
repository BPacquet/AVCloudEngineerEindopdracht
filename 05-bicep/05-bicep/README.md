# 05-bicep — Contoso Manufacturing IaC

> **Tooling:** Azure Bicep | **Scope:** Subscription
> **Architectuur:** Hub-Spoke ALZ Corp | West Europe (prd) | North Europe (dr)
> **Auteur:** bjorn.pacquet@contoso.be

---

## ⚠️ Voor de beoordelaar — wat aanpassen voor deployment

Deze Bicep-bestanden zijn volledig uitgewerkt maar bevatten drie placeholders die
je moet invullen met waarden uit jouw eigen Azure-omgeving.
Volg onderstaande stappen in volgorde.

---

### Stap 1 — Azure CLI installeren en inloggen

```bash
# Azure CLI installeren (indien nog niet aanwezig)
# Windows: https://aka.ms/installazurecliwindows
# Mac:     brew install azure-cli
# Linux:   curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Inloggen
az login

# Controleer welk subscription actief is
az account show --output table
```

---

### Stap 2 — Subscription ID ophalen

Het subscription ID heb je nodig in de parameterbestanden voor de Log Analytics Workspace.

```bash
az account show --query id --output tsv
```

**Voorbeeld output:** `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`

Vervang `<jouw-subscription-id>` in **beide** parameterbestanden door deze waarde:

**`main.bicepparam` — regel aanpassen:**
```bicep
// Vóór:
param logAnalyticsWorkspaceId = '/subscriptions/<jouw-subscription-id>/resourceGroups/...'

// Na (voorbeeld):
param logAnalyticsWorkspaceId = '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/rg-contoso-prd-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-contoso-prd'
```

**`main.dev.bicepparam` — zelfde aanpassing:**
```bicep
param logAnalyticsWorkspaceId = '/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/rg-contoso-dev-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-contoso-dev'
```

> **Waarom dit pad al ingevuld is:** De Log Analytics Workspace wordt aangemaakt
> door de Bicep-deployment zelf. De naam en resource group zijn gekend op basis van
> de naamgevingsconventie. Enkel het subscription ID is nog niet beschikbaar voor deployment.

---

### Stap 3 — Entra ID groepen aanmaken en Object IDs ophalen

De Bicep-bestanden gebruiken Entra ID groepen voor Key Vault en SQL MI toegang.
Dit zijn **geen** resource groups — het zijn gebruikersgroepen in Azure Active Directory.

#### Productie-groep aanmaken

```bash
# Groep aanmaken (eenmalig)
az ad group create \
  --display-name "cloud-platform-engineers" \
  --mail-nickname "cloud-platform-engineers"

# Object ID ophalen
az ad group show \
  --group "cloud-platform-engineers" \
  --query id \
  --output tsv
```

**Voorbeeld output:** `yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy`

Vervang **beide** placeholders in `main.bicepparam`:

```bicep
// Vóór:
param keyVaultAdminObjectId = '00000000-0000-0000-0000-000000000000'
param aadAdminGroupObjectId = '00000000-0000-0000-0000-000000000000'

// Na (voorbeeld — beide dezelfde waarde):
param keyVaultAdminObjectId = 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy'
param aadAdminGroupObjectId = 'yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy'
```

#### Development-groep aanmaken

```bash
az ad group create \
  --display-name "contoso-developers" \
  --mail-nickname "contoso-developers"

az ad group show \
  --group "contoso-developers" \
  --query id \
  --output tsv
```

Vervang in `main.dev.bicepparam`:

```bicep
param keyVaultAdminObjectId = 'zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz'
param aadAdminGroupObjectId = 'zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzz'
```

---

### Stap 4 — SQL-wachtwoord instellen

Het SQL MI admin-wachtwoord wordt via een omgevingsvariabele doorgegeven.
Het staat **nooit** in het parameterbestand zelf.

```bash
# Linux / Mac
export SQL_ADMIN_PASSWORD="<kies-een-sterk-wachtwoord>"
export SQL_ADMIN_PASSWORD_DEV="<kies-een-wachtwoord-voor-dev>"

# Windows PowerShell
$env:SQL_ADMIN_PASSWORD = "<kies-een-sterk-wachtwoord>"
$env:SQL_ADMIN_PASSWORD_DEV = "<kies-een-wachtwoord-voor-dev>"
```

> **Wachtwoordvereisten SQL MI:** minimaal 16 tekens, hoofdletters, kleine letters,
> cijfers en speciale tekens — bv. `Contoso@2025!SecureP4ss`

---

### Stap 5 — Valideren (dry-run)

Controleer eerst wat de deployment zou aanmaken zonder effectief te deployen:

```bash
# Navigeer naar de bicep-map
cd 05-bicep

# Productie validatie
az deployment sub what-if \
  --location westeurope \
  --template-file main.bicep \
  --parameters main.bicepparam

# Development validatie
az deployment sub what-if \
  --location westeurope \
  --template-file main.bicep \
  --parameters main.dev.bicepparam
```

De output toont exact welke resources worden aangemaakt (groen), gewijzigd (oranje)
of verwijderd (rood). Controleer dit voor je verder gaat.

---

### Stap 6 — Effectieve deployment

```bash
# Productie deployen
az deployment sub create \
  --name "contoso-prd-$(date +%Y%m%d-%H%M)" \
  --location westeurope \
  --template-file main.bicep \
  --parameters main.bicepparam

# Development deployen
az deployment sub create \
  --name "contoso-dev-$(date +%Y%m%d-%H%M)" \
  --location westeurope \
  --template-file main.bicep \
  --parameters main.dev.bicepparam
```

---

### Samenvatting — wat aanpassen

| Bestand | Wat aanpassen | Waarde ophalen via |
|---|---|---|
| `main.bicepparam` | `<jouw-subscription-id>` (2x) | `az account show --query id -o tsv` |
| `main.bicepparam` | `00000000-0000-0000-0000-000000000000` (2x) | `az ad group show --group "cloud-platform-engineers" --query id -o tsv` |
| `main.dev.bicepparam` | `<jouw-subscription-id>` (1x) | `az account show --query id -o tsv` |
| `main.dev.bicepparam` | `00000000-0000-0000-0000-000000000000` (2x) | `az ad group show --group "contoso-developers" --query id -o tsv` |
| Omgevingsvariabele | `SQL_ADMIN_PASSWORD` | Zelf kiezen — min. 16 tekens |
| Omgevingsvariabele | `SQL_ADMIN_PASSWORD_DEV` | Zelf kiezen |

---

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

---

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

---

*Versie 1.0 · bjorn.pacquet@contoso.be · West Europe 2025 · INTERN*
