# 06-cicd — CI/CD Pipelines | Contoso Manufacturing

> **Tooling:** Azure DevOps Pipelines (YAML)
> **Omgevingen:** dev (auto) → tst (auto) → prd (manual, 2 approvers)
> **Auteur:** bjorn.pacquet@contoso.be

---

## ⚠️ Voor de beoordelaar — wat aanpassen voor gebruik

De YAML-pipelines zijn volledig uitgewerkt maar kunnen niet draaien zonder een Azure DevOps
organisatie en Azure-subscripties. Onderstaande stappen beschrijven exact wat je moet
instellen en aanpassen om de pipelines werkend te krijgen.

---

### Stap 1 — Azure DevOps project aanmaken

1. Ga naar [dev.azure.com](https://dev.azure.com) en log in
2. Maak een nieuwe organisatie aan (of gebruik een bestaande)
3. Maak een nieuw project aan:
   - **Naam:** `contoso-manufacturing`
   - **Visibility:** Private
   - **Version control:** Git
4. Importeer of push de broncode naar de Azure DevOps Git repository

---

### Stap 2 — Pipelines aanmaken

Maak twee pipelines aan via **Pipelines → New pipeline → Azure Repos Git → Existing YAML file**:

| Pipeline naam | YAML bestand | Beschrijving |
|---|---|---|
| `IaC Deploy — Contoso` | `06-cicd/iac-pipeline.yml` | Bicep infrastructure deployment |
| `App Deploy — Contoso` | `06-cicd/app-pipeline.yml` | .NET applicatie build en deploy |

---

### Stap 3 — Service Connections aanmaken

Ga naar **Project Settings → Service connections → New service connection**.

Maak de volgende vier service connections aan via **Azure Resource Manager → Workload Identity federation (automatisch)** — dit is de aanbevolen methode zonder client secrets:

| Naam in YAML | Type | Subscription scope | Aanmaken |
|---|---|---|---|
| `sc-azure-dev` | Azure Resource Manager | Dev subscription | Project Settings → Service connections → New → ARM → WIF |
| `sc-azure-tst` | Azure Resource Manager | Tst subscription | idem |
| `sc-azure-prd` | Azure Resource Manager | Prd subscription | idem |
| `sc-sonarcloud` | SonarCloud | — | New → SonarCloud → Token uit sonarcloud.io |

> **Belangrijk:** De namen in de service connections moeten exact overeenkomen met
> de namen in de YAML-bestanden (`sc-azure-dev`, `sc-azure-tst`, `sc-azure-prd`, `sc-sonarcloud`).
> Als je andere namen gebruikt, pas dan alle vermeldingen in beide YAML-bestanden aan.

---

### Stap 4 — Variable Groups aanmaken

Ga naar **Pipelines → Library → + Variable group**.

#### 4a. `contoso-common` — gedeelde waarden

| Variabele | Waarde | Geheim? |
|---|---|:---:|
| `azureLocation` | `westeurope` | ❌ |
| `appName` | `contoso` | ❌ |
| `sonarOrganization` | jouw SonarCloud organisatienaam | ❌ |
| `sonarProjectKey` | `contoso-manufacturing_web` | ❌ |

#### 4b. `contoso-dev-secrets` / `contoso-tst-secrets` / `contoso-prd-secrets`

Maak drie aparte variable groups aan — één per omgeving.
Voeg de volgende variabelen toe als **geheime variabelen** (slotje-icoon aanklikken):

| Variabele | Waarde | Geheim? |
|---|---|:---:|
| `sqlAdminPassword` | het SQL MI wachtwoord (zie Bicep stap 4) | ✅ |
| `keyVaultAdminObjectId` | Entra ID groep Object ID (zie Bicep stap 3) | ✅ |
| `aadAdminGroupObjectId` | zelfde als hierboven | ✅ |
| `aadAdminGroupName` | `cloud-platform-engineers` (prd) / `contoso-developers` (dev) | ❌ |
| `logAnalyticsWorkspaceId` | volledige resource ID van de LAW (zie Bicep stap 2) | ❌ |
| `drServerName` | `sql-contoso-prd-dr-001` (enkel in prd-secrets) | ❌ |
| `sonarToken` | token uit sonarcloud.io | ✅ |

> **Tip:** Koppel de `*-secrets` groups aan Key Vault via **"Link secrets from an Azure key vault"**
> zodra de Bicep-deployment is uitgerold. Dan hoef je de waarden niet handmatig in te voeren.

#### 4c. `contoso-dev` / `contoso-tst` / `contoso-prd`

| Variabele | dev | tst | prd |
|---|---|---|---|
| `webAppName` | `web-contoso-dev` | `web-contoso-tst` | `web-contoso-prd` |
| `resourceGroup` | `rg-contoso-dev-frontend` | `rg-contoso-tst-frontend` | `rg-contoso-prd-frontend` |

---

### Stap 5 — Environments aanmaken

Ga naar **Pipelines → Environments → New environment**.

Maak drie environments aan:

| Naam | Beschrijving | Approval? |
|---|---|:---:|
| `dev` | Development omgeving | ❌ |
| `tst` | Test omgeving | ❌ |
| `prd` | Productie omgeving | ✅ verplicht |

#### Approval gate instellen op `prd`

1. Open environment `prd` → klik **⋯ → Approvals and checks**
2. Klik **+** → **Approvals** en configureer:

```
Approvers        : bjorn.pacquet@contoso.be  +  <naam tech lead>
Minimum aantal   : 2
Eigen run keuren : ❌ Nee
Timeout          : 24 uur
Instructies      : "Controleer TST-omgeving op https://web-contoso-tst.azurewebsites.net
                    en bevestig akkoord voor productie-deployment."
```

3. Klik **+** → **Business hours** en configureer:

```
Tijdzone      : (UTC+01:00) Brussels, Copenhagen, Madrid, Paris
Werkdagen     : maandag t/m vrijdag
Werkuren      : 08:00 – 18:00
```

---

### Stap 6 — App-namen aanpassen in de YAML-bestanden

De YAML-bestanden gebruiken App Service namen gebaseerd op de Bicep naamgevingsconventie.
Controleer dat deze namen overeenkomen met wat je Bicep aanmaakt:

**In `app-pipeline.yml` — controleer/pas aan:**

| Regel | Huidige waarde | Jouw waarde |
|---|---|---|
| Smoke test DEV | `web-contoso-dev.azurewebsites.net` | `web-contoso-dev.azurewebsites.net` ✅ |
| App name DEV deploy | `web-contoso-dev` | `web-contoso-dev` ✅ |
| Staging test TST | `web-contoso-tst-staging.azurewebsites.net` | `web-contoso-tst-staging.azurewebsites.net` ✅ |
| App name TST deploy | `web-contoso-tst` | `web-contoso-tst` ✅ |
| Staging test PRD | `web-contoso-prd-staging.azurewebsites.net` | `web-contoso-prd-staging.azurewebsites.net` ✅ |
| App name PRD deploy | `web-contoso-prd` | `web-contoso-prd` ✅ |

> Als je de `appName` of `environment` parameters in je Bicep-parameterbestanden
> hebt gewijzigd, pas dan ook de App Service namen in de YAML aan.

---

### Stap 7 — Broncode aanvullen (twee onderdelen)

#### 7a. Health check endpoint

De pipelines controleren `/health` op elke omgeving na deployment.
Voeg dit endpoint toe aan je ASP.NET WebForms applicatie:

Maak een bestand `Health.aspx` aan in de root van je webproject:

```aspx
<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Health.aspx.cs" Inherits="Contoso.Web.Health" %>
```

En `Health.aspx.cs`:

```csharp
using System;
using System.Web.UI;

namespace Contoso.Web
{
    public partial class Health : Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            // Optioneel: controleer database-connectiviteit
            Response.StatusCode = 200;
            Response.ContentType = "text/plain";
            Response.Write("Healthy");
            Response.End();
        }
    }
}
```

#### 7b. Integratietest project

De `app-pipeline.yml` verwijst naar `src/Contoso.IntegrationTests/Contoso.IntegrationTests.csproj`.

**Optie A — project aanmaken:**
```bash
dotnet new mstest -n Contoso.IntegrationTests -o src/Contoso.IntegrationTests
```

**Optie B — pad aanpassen in YAML** als je een ander testproject hebt:
```yaml
# In app-pipeline.yml — regel ~20
- name: integrationTestProjectPath
  value: 'src/JouwBestaandTestProject/JouwProject.csproj'
```

---

### Stap 8 — SonarCloud account aanmaken (SAST)

1. Ga naar [sonarcloud.io](https://sonarcloud.io) en log in met je Azure DevOps account
2. Maak een organisatie aan genaamd `contoso-manufacturing`
3. Voeg het project toe: **+ Analyze new project → Azure DevOps → contoso-manufacturing**
4. Kopieer de **Project Key** (bv. `contoso-manufacturing_web`)
5. Genereer een **User Token** via My Account → Security → Generate Token
6. Sla de token op in de variable group `contoso-common` als `sonarToken` (geheim)

Vul de waarden in `contoso-common` aan:

```
sonarOrganization : contoso-manufacturing   (jouw SonarCloud organisatienaam)
sonarProjectKey   : contoso-manufacturing_web
```

> **Geen SonarCloud account?** Commentarieer de drie SonarCloud taken tijdelijk uit
> in `app-pipeline.yml` (regels `SonarCloudPrepare`, `SonarCloudAnalyze`, `SonarCloudPublish`).
> De rest van de pipeline werkt dan nog steeds.

---

### Samenvatting — wat aanpassen

| # | Actie | Waar | Bestanden aanpassen? |
|---|---|---|:---:|
| 1 | Azure DevOps project aanmaken | dev.azure.com | ❌ |
| 2 | Twee pipelines aanmaken (IaC + App) | Pipelines → New pipeline | ❌ |
| 3 | 4 service connections aanmaken | Project Settings → Service connections | ❌ |
| 4 | 7 variable groups aanmaken en vullen | Pipelines → Library | ❌ |
| 5 | 3 environments aanmaken + approval op prd | Pipelines → Environments | ❌ |
| 6 | App-namen controleren (kloppen al) | `app-pipeline.yml` | Waarschijnlijk ❌ |
| 7a | `/health` endpoint toevoegen aan broncode | `src/Contoso.Web/Health.aspx` | ✅ |
| 7b | Integratietest project aanmaken of pad aanpassen | `app-pipeline.yml` regel ~20 | ✅ |
| 8 | SonarCloud account + token | sonarcloud.io + variable group | ✅ |

---

## Bestanden

```
06-cicd/
├── README.md           ← dit bestand
├── iac-pipeline.yml    ← IaC pipeline: Bicep deployments
└── app-pipeline.yml    ← App pipeline: build, test, deploy ASP.NET
```

---

## Pipeline overzicht

### Omgevingen en triggers

| Omgeving | Branch | Auto-deploy | Approval |
|---|---|:---:|:---:|
| dev | `feature/*`, `develop`, `main` | ✅ | ❌ |
| tst | `develop`, `main` | ✅ | ❌ |
| prd | `main` | ❌ | ✅ 2 approvers |

### Service Connections

Alle service connections gebruiken **Workload Identity Federation (OIDC)** — geen client secrets opgeslagen in Azure DevOps.

| Naam | Type | Scope | Gebruik |
|---|---|---|---|
| `sc-azure-dev` | Azure Resource Manager (WIF) | Dev Subscription | IaC + App deploy dev |
| `sc-azure-tst` | Azure Resource Manager (WIF) | Tst Subscription | IaC + App deploy tst |
| `sc-azure-prd` | Azure Resource Manager (WIF) | Prd Subscription | IaC + App deploy prd |
| `sc-sonarcloud` | SonarCloud | — | SAST analyse |

---

## IaC Pipeline (iac-pipeline.yml)

### Flow

```
Validate
  ├── Lint (alle .bicep bestanden)
  ├── Build (compileren naar ARM JSON)
  ├── What-If DEV
  └── What-If TST
      │
      ▼
Deploy DEV (auto — alle branches)
      │
      ▼ (alleen develop/main)
Deploy TST (auto)
      │
      ▼ (alleen main + 2 approvers)
Deploy PRD
      │ (bij falen)
      ▼
Rollback PRD (annuleer deployment + instructies)
```

### Keuzes en onderbouwing

**What-If vóór elke deployment** — De `az deployment sub what-if` stap toont exact welke resources worden aangemaakt, gewijzigd of verwijderd. Approvers kunnen dit rapport reviewen vóór de PRD-deployment.

**Secrets via variable groups + Key Vault** — Geen plaintext secrets in YAML. Alle gevoelige waarden komen uit Key Vault via de Library Key Vault link.

**Finale What-If in PRD deploy stap** — Net voor de effectieve deployment wordt nogmaals een What-If uitgevoerd zodat de approver de exacte wijzigingen ziet.

---

## App Pipeline (app-pipeline.yml)

### Flow

```
Build
  ├── SonarCloud Prepare (SAST)
  ├── dotnet restore / build
  ├── Unit tests + code coverage
  ├── SonarCloud Analyze + Quality Gate
  ├── NuGet vulnerability scan
  └── dotnet publish → artifact
      │
      ├── SecurityScan (OWASP ZAP DAST — parallel)
      │
      ▼
Deploy DEV (auto)
  └── Smoke test /health
      │
      ▼ (develop/main)
Deploy TST
  ├── Deploy naar staging slot
  ├── Integratietests op staging
  ├── Health check staging
  ├── Swap staging → production
  └── Verificatie production
      │
      ▼ (main + 2 approvers)
Deploy PRD
  ├── Deploy naar staging slot
  ├── Health check staging
  ├── Swap staging → production
  └── Verificatie production
      │ (bij falen)
      ▼
Rollback PRD
  ├── Swap production → staging (terug)
  └── Verificatie rollback
```

### Keuzes en onderbouwing

**SonarCloud als SAST-tool** — Geïntegreerd via `SonarCloudPrepare`, `SonarCloudAnalyze` en `SonarCloudPublish` tasks. Quality Gate blokkeert bij Critical/Blocker bevindingen.

**OWASP ZAP als DAST-tool** — Baseline scan op de DEV-omgeving na deployment. Passieve scan — geen actieve aanvallen.

**Staging slot strategie** — In TST en PRD wordt altijd naar de staging slot gedeployed. Production blijft draaiend op de vorige versie tot na een geslaagde health check.

**Windows build agent** — `windows-latest` is verplicht voor ASP.NET WebForms op .NET Framework 4.8.

---

## Rollback strategie

### App Service rollback

| Scenario | Actie | Tijd |
|---|---|---|
| Health check mislukt op staging | Swap wordt **niet** uitgevoerd — production onaangetast | Direct |
| Probleem ontdekt na swap in PRD | `Rollback_Prd` stage swapt automatisch terug | < 2 min |
| Rollback_Prd ook mislukt | Manuele swap via CLI (zie commando) | Direct |

```bash
# Manuele rollback via CLI
az webapp deployment slot swap \
  --resource-group rg-contoso-prd-frontend \
  --name web-contoso-prd \
  --slot staging \
  --target-slot production
```

### IaC rollback

| Scenario | Actie |
|---|---|
| Bicep deployment mislukt | `az deployment sub cancel --name <naam>` → corrigeer → herdeployeer |
| Volledige rollback vereist | `git revert HEAD --no-edit && git push` → pipeline herstart |

---

## NIS2 compliance

| NIS2 Art. | Maatregel in CI/CD |
|---|---|
| Art. 21(2)(a) risicoanalyse | NuGet vulnerability scan + OWASP ZAP DAST |
| Art. 21(2)(b) monitoring | SonarCloud Quality Gate + health checks |
| Art. 21(2)(e) toegangscontrole | WIF service connections (geen secrets) + 2 approvers PRD |
| Art. 21(2)(h) cryptografie | HTTPS-only health checks + TLS 1.2 op alle endpoints |

---

*Versie 1.0 · bjorn.pacquet@contoso.be · West Europe 2025 · INTERN*
