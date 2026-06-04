# 04 — security governance documentatie

> **Deliverable**: Azure Policy, RBAC, Defender for Cloud, Key Vault, NIS2  
> **Gewicht**: 20% van de totale eindopdrachtscore

---

## opdracht

Ontwerp de volledige **security governance** voor de Contoso-omgeving in Azure. Security is geen bijzaak — in de Belgische context (NIS2) en met een productiebedrijf als klant is dit een kritiek onderdeel.

---

## deel A: azure policy

### doel

Azure Policy dwingt compliance af en voorkomt misconfiguraties voordat ze productie bereiken. Documenteer welke policies je toewijst en op welk niveau (Management Group, Subscription, Resource Group).

### vereiste policy-categorieën

#### 1. Tagging beleid

Alle resources **moeten** de volgende tags hebben. Maak een `deny`-policy die resources zonder deze tags weigert:

| Tag | Voorbeeld waarde | Verplicht? |
|---|---|---|
| `Environment` | `prd`, `tst`, `dev` | ✅ |
| `Application` | `contoso-manufacturing` | ✅ |
| `Owner` | `team-cloud@contoso.be` | ✅ |
| `CostCenter` | `CC-IT-001` | ✅ |
| `DataClassification` | `internal`, `confidential` | ✅ |

#### 2. Verplichte beveiligingsinstellingen

| Policy | Effect | Niveau |
|---|---|---|
| Require HTTPS on App Service | `Deny` | Subscription |
| Disable public network access on SQL DB | `Deny` | Subscription |
| Require Minimum TLS 1.2 on Storage | `Deny` | Subscription |
| Key Vault should have purge protection | `Deny` | Subscription |
| Allowed locations | `Deny` | Management Group |
| Allowed resource types (optioneel) | `Deny` | Subscription |

#### 3. Audit policies (Defender for Cloud)

Wijs de **Azure Security Benchmark** initiative toe op Management Group-niveau. Documenteer welke controls je prioriteit geeft voor Contoso.

### policy definitie voorbeeld

```json
{
  "displayName": "Require tag 'Environment' on all resources",
  "description": "Enforces the presence of the 'Environment' tag on all resources.",
  "policyRule": {
    "if": {
      "allOf": [
        {
          "field": "tags['Environment']",
          "exists": "false"
        }
      ]
    },
    "then": {
      "effect": "deny"
    }
  }
}
```

**Opdracht**: Maak Policy-definitie JSON-bestanden voor minimaal:
- [ ] Tagging policy (Environment tag)
- [ ] HTTPS only op App Service
- [ ] Disable public access op SQL Database
- [ ] Allowed locations (West Europe + North Europe only)

Sla op als `04-security/policies/policy-*.json`

---

## deel B: RBAC (role-based access control)

### principe: least privilege

Documenteer de **RBAC-toewijzingen** voor elke persona die met de Contoso-omgeving werkt.

### persona's

| Persona | Azure RBAC Rol | Scope | Motivering |
|---|---|---|---|
| Cloud Platform Engineer | `Owner` | Connectivity Subscription | Beheert hub networking |
| Cloud Platform Engineer | `Contributor` | Management Subscription | Beheert monitoring/automation |
| Application Developer | `Contributor` | Resource Groups in NonProd | Deploy nieuwe versies |
| Application Developer | `Reader` | Resource Groups in Prod | Read-only in productie |
| DevOps/CI-CD Service Principal | `Contributor` | Workload Subscription (beperkt) | IaC deployments |
| Security Analyst | `Security Reader` | Management Group root | Audit Defender for Cloud |
| Backup Operator | `Backup Contributor` | Workload Subscription | Beheer backups |
| SAP Integration Service | `Storage Blob Data Reader` | Storage Account (specifiek) | Lees rapporten |
| Database Admin | `SQL DB Contributor` | SQL Server resource | DB beheer, geen infra |
| Support (L1/L2) | `Reader` | Workload Resource Groups | Read-only monitoring |

### custom role voorbeeld

Maak een **custom RBAC-rol** voor een "Contoso App Deployer" die enkel App Service deployments mag uitvoeren:

```json
{
  "Name": "Contoso Application Deployer",
  "Description": "Deploy application code and perform slot swaps on App Services. No access to networking, security, infrastructure or configuration settings.",
  "Actions": [
    "Microsoft.Web/sites/read",
    "Microsoft.Web/sites/config/read",
    "Microsoft.Web/sites/slots/read",
    "Microsoft.Web/sites/publish/action",
    "Microsoft.Web/sites/slots/publish/action",
    "Microsoft.Web/sites/slots/slotsswap/action",
    "Microsoft.Insights/metrics/read",
    "Microsoft.Insights/logs/read"
  ],
  "NotActions": [
    "Microsoft.Web/sites/write",
    "Microsoft.Web/sites/delete",
    "Microsoft.Web/sites/config/write",
    "Microsoft.Network/*",
    "Microsoft.Authorization/*",
    "Microsoft.KeyVault/*",
    "Microsoft.Compute/*"
  ],
  "DataActions": [],
  "NotDataActions": [],
  "AssignableScopes": [
    "/subscriptions/{subscriptionId}/resourceGroups/rg-app-prod",
    "/subscriptions/{subscriptionId}/resourceGroups/rg-app-nonprod"
  ]
}
```

**Opdracht**: Pas bovenstaand voorbeeld aan en documenteer je keuzes.

# Verantwoording keuzes – Custom RBAC Rol

## Contoso Application Deployer

### Doel van de rol
De custom rol **Contoso Application Deployer** is ontworpen volgens het **Least Privilege-principe**. De rol biedt uitsluitend de rechten die nodig zijn om applicaties naar Azure App Services te deployen en deployments te valideren, zonder toegang te geven tot infrastructuur-, netwerk- of beveiligingscomponenten.

---

## 1. Alleen applicatiedeployment

**Toegestane actie**

- `Microsoft.Web/sites/publish/action`

### Motivatie
Met deze actie kan een ontwikkelaar of CI/CD-pipeline nieuwe applicatiecode publiceren naar een bestaande App Service zonder wijzigingen aan de onderliggende infrastructuur.

### Voordelen
- Ondersteunt CI/CD-processen.
- Vermindert risico op ongecontroleerde infrastructuurwijzigingen.
- Duidelijke scheiding tussen platformbeheer en applicatiebeheer.

---

## 2. Slot Swapping

**Toegestane actie**

- `Microsoft.Web/sites/slots/slotsswap/action`

### Motivatie
Ondersteunt een deploymentstrategie met deployment slots (bijvoorbeeld staging en productie). Nieuwe versies kunnen eerst worden getest voordat ze naar productie worden omgewisseld.

### Voordelen
- Zero-downtime deployments.
- Lagere kans op verstoringen in productie.
- Snelle rollback-mogelijkheden.
---
## 3. Read-only configuratie
**Toegestane actie**
- `Microsoft.Web/sites/config/read`
**Niet toegestaan**
- `Microsoft.Web/sites/config/write`
### Motivatie
Applicatiebeheerders moeten kunnen controleren welke configuratie actief is, maar mogen deze niet wijzigen.

### Voordelen
- Voorkomt configuratiedrift.
- Waarborgt Infrastructure-as-Code governance.
- Verkleint het risico op foutieve productieaanpassingen.
---
## 4. Monitoring en validatie
**Toegestane acties**
- `Microsoft.Insights/metrics/read`
- `Microsoft.Insights/logs/read`
### Motivatie
Na een deployment moet een ontwikkelaar kunnen controleren of de applicatie correct functioneert.

### Voordelen
- Zelfstandig uitvoeren van validaties.
- Snellere probleemoplossing.
- Minder afhankelijkheid van Operations-teams.
---
## 5. Geen infrastructuurbeheer
**Uitgesloten acties**

- `Microsoft.Network/*`
- `Microsoft.Compute/*`
- `Microsoft.Authorization/*`
### Motivatie
Netwerk-, compute- en RBAC-beheer behoren tot de verantwoordelijkheid van het Platform Team.

### Voordelen
- Bescherming van de Landing Zone architectuur.
- Voorkomt ongeautoriseerde wijzigingen.
- Duidelijke taakverdeling tussen teams.
---
## 6. Geen toegang tot Key Vault
**Uitgesloten acties**
- `Microsoft.KeyVault/*`
### Motivatie
Secrets worden beheerd via Managed Identities, Key Vault RBAC en het Security Team.

### Voordelen
- Bescherming van gevoelige gegevens.
- Vermindering van insider-risico's.
- Betere naleving van security policies.
---
# Conclusie

De rol **Contoso Application Deployer** biedt precies voldoende rechten om applicaties veilig te deployen en te beheren binnen de Contoso Azure Landing Zone. Door infrastructuur-, netwerk-, security- en configuratierechten uit te sluiten, sluit de rol volledig aan op het Least Privilege-principe en de governance-richtlijnen van de organisatie.

# Deel C – Microsoft Defender for Cloud

## 1. Planselectie

Binnen de Contoso Manufacturing Azure Landing Zone wordt Microsoft Defender for Cloud gebruikt om de beveiligingspositie van de omgeving continu te monitoren en bedreigingen vroegtijdig te detecteren. Per resourcetype wordt een afweging gemaakt tussen kostprijs en beveiligingswaarde.

### Defender-plannen per resource type

| Resource Type | Defender Plan | Maandkost (indicatief) | Activeren? | Motivering |
|---------------|--------------|------------------------|------------|------------|
| Azure SQL Managed Instance | Defender for SQL | ± €15/instance/maand | ✅ Ja | De SQL Managed Instance bevat bedrijfskritische data. Defender for SQL biedt Vulnerability Assessment, Threat Detection en Advanced Threat Protection tegen SQL-injecties, verdachte logins en misbruik van databanken. |
| App Service | Defender for App Service | ± €15/App Service Plan/maand | ✅ Ja | De webapplicatie is extern bereikbaar via Azure Front Door en Application Gateway. Defender detecteert kwetsbaarheden, verdachte activiteiten en configuratiefouten binnen de applicatielaag. |
| Storage Account | Defender for Storage | Verbruiksgebaseerd | ✅ Ja | De Storage Account bevat applicatiegegevens, rapporten en exports. Defender detecteert malware, verdachte toegangspatronen en mogelijke datalekken. |
| Azure Key Vault | Defender for Key Vault | ± €0,02 per 10.000 operaties | ✅ Ja | Key Vault bevat secrets, certificaten en connection strings. Een compromis van deze component zou impact hebben op de volledige applicatieomgeving. De beveiligingswaarde is hoog terwijl de kost verwaarloosbaar blijft. |
| Azure Resource Manager | Defender for Resource Manager | ± €4/subscription/maand | ✅ Ja | Detecteert verdachte wijzigingen, privilege-escalaties en ongeautoriseerde beheeracties binnen Azure-resources. |
| Domain Controllers & Management VM's | Defender for Servers P2 | ± €15/server/maand | ✅ Ja | De omgeving bevat Azure VM's voor Active Directory Domain Controllers en identiteitsservices. Defender for Servers P2 biedt Endpoint Detection & Response (EDR), Vulnerability Assessment, Just-In-Time Access en detectie van laterale bewegingen. |

---

## 2. Verantwoording van de gekozen strategie

De ontworpen Azure Landing Zone volgt een **PaaS-first strategie**, maar bevat ook enkele kritieke virtuele machines voor identiteitsbeheer.

Microsoft Defender for Cloud wordt daarom geactiveerd op alle componenten die:

- bedrijfskritische gegevens bevatten;
- publiek toegankelijk zijn;
- identiteiten beheren;
- toegang geven tot andere systemen;
- een hoog risico vormen bij compromittering.

Deze aanpak zorgt voor een optimale balans tussen beveiliging en kostenbeheersing.

### Waarom Defender for SQL?

Azure SQL Managed Instance bevat standaard reeds verschillende beveiligingsfuncties zoals:

- Transparent Data Encryption (TDE)
- Firewallregels
- Back-ups
- High Availability
- Auditing

Deze functionaliteiten beschermen echter niet tegen geavanceerde aanvallen of foutieve configuraties.

Door **Defender for SQL** te activeren worden extra beveiligingslagen toegevoegd:

- Vulnerability Assessment
- Threat Detection
- Detectie van SQL-injecties
- Detectie van verdachte login-patronen
- Beveiligingsaanbevelingen binnen Defender for Cloud

Aangezien de SQL Managed Instance de centrale databron van de applicatie vormt, wordt dit Defender-plan als essentieel beschouwd.

### Waarom Defender for Servers P2?

Hoewel de workload grotendeels bestaat uit Azure PaaS-diensten, bevat de architectuur ook:

- Active Directory Domain Controllers
- Entra Connect Sync server
- Managementservers

Deze systemen vormen de basis van de hybride identiteitsarchitectuur. Een succesvolle aanval op een Domain Controller kan leiden tot volledige compromittering van zowel Azure- als on-premises identiteiten.

Daarom wordt Defender for Servers P2 geactiveerd om:

- kwetsbaarheden automatisch te detecteren;
- Endpoint Detection & Response (EDR) te voorzien;
- laterale bewegingen te detecteren;
- beheerpoorten te beschermen via Just-In-Time Access.

---

# 3. Secure Score Doelstelling

## Doelstelling

Voor de productieomgeving wordt een **Microsoft Secure Score van minimaal 80%** nagestreefd.

Deze score biedt een goede balans tussen:

- beveiliging;
- operationele haalbaarheid;
- beheerkost;
- compliance met Microsoft best practices.

Door gebruik te maken van Azure Policy, Microsoft Defender for Cloud en de Azure Landing Zone architectuur kan deze score duurzaam worden behaald.

---

## Prioritaire aanbevelingen

| Prioriteit | Aanbeveling | Score Impact | Motivatie |
|------------|-------------|--------------|-----------|
| 🔴 Kritiek | Enable MFA for all users | Hoog | Multi-Factor Authentication voorkomt misbruik van gecompromitteerde accounts en vormt een essentieel onderdeel van het Zero Trust-model. |
| 🔴 Kritiek | Disable public network access | Hoog | SQL MI, Storage Accounts, Key Vault en Service Bus zijn uitsluitend bereikbaar via Private Endpoints. Hierdoor wordt het aanvalsvlak aanzienlijk verkleind. |
| 🔴 Kritiek | Enable Defender for Servers P2 | Hoog | Bescherming van Domain Controllers en identiteitsservers tegen geavanceerde aanvallen. |
| 🟠 Hoog | Enable Defender for SQL | Middel | Detecteert databaseaanvallen, kwetsbaarheden en verdachte activiteiten binnen SQL Managed Instance. |
| 🟠 Hoog | Enable Defender for App Service | Middel | Beschermt de publiek toegankelijke applicatielaag tegen kwetsbaarheden en aanvallen. |
| 🟡 Middel | Configure Just-In-Time Access | Laag | Vermindert blootstelling van beheerinterfaces op managementservers. |
| 🟡 Middel | Apply System Updates | Laag | Houdt alle VM's en beheersystemen up-to-date met de laatste beveiligingsupdates. |
| 🟡 Middel | Enable Continuous Monitoring | Laag | Verzamelt beveiligingslogs via Azure Monitor, Log Analytics en Microsoft Sentinel. |

---

# 4. Verwacht Resultaat

Door de implementatie van Microsoft Defender for Cloud wordt verwacht dat de omgeving:

- een Secure Score van minimaal **80%** behaalt;
- voldoet aan de principes van **Zero Trust Security**;
- voldoet aan de aanbevelingen van het **Microsoft Cloud Adoption Framework (CAF)**;
- voldoet aan de **Azure Landing Zone Reference Architecture**;
- bedreigingen sneller detecteert en hierop kan reageren;
- een hogere beveiligingsvolwassenheid bereikt zonder een significante stijging van de operationele kosten.

De combinatie van Microsoft Defender for Cloud, Azure Policy, Private Endpoints, Azure Firewall Premium en Microsoft Sentinel zorgt voor een gelaagde beveiligingsarchitectuur die geschikt is voor een productieomgeving van Contoso Manufacturing NV.

## deel D: key vault architectuur

### vereisten

Documenteer de Key Vault-architectuur voor de Contoso-omgeving.

### secrets, keys en certificates

| Type | Naam (voorbeeld) | Beschrijving | Rotatie |
|---|---|---|---|
| **Secret** | `sql-connection-string` | Connection string SQL Database | 90 dagen |
| **Secret** | `smtp-password` | SMTP relay wachtwoord | 180 dagen |
| **Secret** | `sap-api-key` | SAP REST API key | 90 dagen |
| **Key** | `cmk-sql-encryption` | Customer Managed Key voor SQL TDE | 1 jaar |
| **Key** | `cmk-storage-encryption` | Customer Managed Key voor Storage | 1 jaar |
| **Certificate** | `ssl-contoso-app` | TLS/SSL certificaat App Service | 1 jaar (auto-renew) |

### toegangsbeleid

Gebruik **RBAC voor Key Vault** (niet het legacy access policy model).

| Wie/Wat | Key Vault RBAC Rol | Reden |
|---|---|---|
| App Service (Managed Identity) | `Key Vault Secrets User` | Lees secrets at runtime |
| Azure Functions (Managed Identity) | `Key Vault Secrets User` | Lees secrets at runtime |
| App Service (Managed Identity) | `Key Vault Crypto User` | Gebruik CMK voor encryptie |
| DevOps Pipeline (Service Principal) | `Key Vault Secrets Officer` | Schrijf/update secrets via pipeline |
| Cloud Platform Engineer | `Key Vault Administrator` | Volledig beheer |
| Security Analyst | `Key Vault Reader` | Audit toegang |

### managed identity gebruik

Documenteer hoe **Managed Identity** gebruikt wordt om wachtwoorden uit de applicatiecode te verwijderen:

```
App Service
    │
    │ (System Assigned Managed Identity)
    ▼
Azure Entra ID (automatisch token)
    │
    ▼
Key Vault (RBAC: Key Vault Secrets User)
    │
    ▼
Secret: "sql-connection-string"
    │
    ▼
Azure SQL Database (via Private Endpoint)
```

**Opdracht**: Beschrijf in code (C# of Python) hoe de applicatie de connection string ophaalt via de DefaultAzureCredential zonder hardcoded wachtwoorden.

---

## deel E: NIS2-compliance mapping

### belgische context

België heeft NIS2 omgezet in nationale wetgeving via de **Wet van 26 april 2024**. Als productiebedrijf valt Contoso Manufacturing mogelijks onder de **"belangrijke entiteiten"**-categorie.

### NIS2 vereisten mapping

| NIS2 Artikel | Vereiste | Azure Implementatie |
|---|---|---|
| Art. 21(2)(a) | Beleid voor risicoanalyse en informatiebeveiliging | Defender for Cloud + Security Baseline |
| Art. 21(2)(b) | Incidentafhandeling | Microsoft Sentinel of Defender XDR |
| Art. 21(2)(c) | Bedrijfscontinuïteit, back-up, DR | Azure Backup + SQL geo-replication + DR plan |
| Art. 21(2)(d) | Beveiliging van de supply chain | Defender for Cloud Supply Chain security |
| Art. 21(2)(e) | Beveiliging bij verwerving, ontwikkeling, onderhoud van netwerken | Secure DevOps (SAST, DAST in pipeline) |
| Art. 21(2)(f) | Beleid voor beoordeling effectiviteit maatregelen | Defender Secure Score + maandelijkse audit |
| Art. 21(2)(g) | Cyberhygiëne en cybersecuritytraining | Microsoft Security training + awareness |
| Art. 21(2)(h) | Beleid gebruik cryptografie | Key Vault CMK, TLS 1.2+, encrypted at rest |
| Art. 21(2)(i) | Beveiliging van personeel, toegangsbeleid | MFA, PIM, RBAC least privilege |
| Art. 21(2)(j) | Authenticatie met meerdere factoren | Entra ID MFA + Conditional Access |

### meldingsplicht

Documenteer het **incidentmeldingsproces** conform NIS2:

```
Incident detectie (Defender for Cloud / Sentinel alert)
    │
    ▼ (binnen 24 uur)
Initiële melding aan CCB (Centrum voor Cybersecurity België)
via https://ccb.belgium.be/nl/meld-een-incident
    │
    ▼ (binnen 72 uur)
Gedetailleerde melding met impact en maatregelen
    │
    ▼ (binnen 1 maand)
Eindrapport met oorzaakanalyse en preventieve maatregelen
```

---

## wat je inlevert

```
04-security/
├── README.md                    ← dit bestand, volledig ingevuld
└── policies/
    ├── policy-require-env-tag.json
    ├── policy-https-only-appservice.json
    ├── policy-no-public-sql.json
    └── policy-allowed-locations.json
```

---

## beoordelingscriteria (20 punten)

| Criterium | Punten |
|---|---|
| Azure Policy: min. 4 policies gedocumenteerd + JSON | 5 |
| RBAC: alle persona's + custom role | 4 |
| Defender for Cloud: plan selectie met motivering | 3 |
| Key Vault architectuur volledig (secrets/keys/certs, MI) | 4 |
| NIS2 mapping correct en volledig | 4 |

---

_Ga verder naar [`../05-bicep/README.md`](../05-bicep/README.md)_

---
