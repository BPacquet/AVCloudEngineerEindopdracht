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
# NIS2 Incidentmeldingsproces — Contoso Manufacturing

> **Wettelijk kader:** NIS2-richtlijn (EU 2022/2555) · omgezet in Belgisch recht via de NIS2-wet
> **Bevoegde autoriteit:** CCB — Centrum voor Cybersecurity België
> **Meldingsportaal:** https://ccb.belgium.be/nl/meld-een-incident
> **NIS2-contactpersoon Contoso:** team-cloud@contoso.be
> **DPO (GDPR Art. 33):** dpo@contoso.be

---

## Inhoudsopgave

- [Wanneer is een incident meldingsplichtig?](#wanneer-is-een-incident-meldingsplichtig)
- [Tijdlijn overzicht](#tijdlijn-overzicht)
- [Fase 0 — Detectie & eerste beoordeling](#fase-0--detectie--eerste-beoordeling-t0--t2u)
- [Fase 1 — Initiële melding (24u)](#fase-1--initiële-melding-24-uur)
- [Fase 2 — Gedetailleerde melding (72u)](#fase-2--gedetailleerde-melding-72-uur)
- [Fase 3 — Eindrapport (1 maand)](#fase-3--eindrapport-1-maand)
- [Interne escalatiepad](#interne-escalatiepad)
- [Contoso-specifieke detectiebronnen](#contoso-specifieke-detectiebronnen)
- [GDPR koppeling](#gdpr-koppeling-art-33)

---

## Wanneer is een incident meldingsplichtig?

Een incident is meldingsplichtig aan het CCB wanneer het een **significante verstoring** veroorzaakt van de dienstverlening, of wanneer er aanwijzingen zijn van een **doelbewuste aanval** op netwerk- of informatiesystemen.

Indicatoren voor Contoso Manufacturing:

| Indicator | Voorbeeld |
|---|---|
| Dienstverlening verstoord | web-contoso-prd onbereikbaar voor > 30 min |
| Dataverlies of -diefstal | Ongeautoriseerde toegang tot sql-contoso-prd-001 |
| Ransomware / encryptie | Bestanden in Blob Storage versleuteld |
| Credential compromise | Ongeautoriseerde PIM-activatie of Key Vault-toegang |
| Supply chain aanval | Compromitteerde DevOps-pipeline of Bicep-module |
| DDoS | Aanhoudende volumetrische aanval op pip-agw-prd |

> **Bij twijfel: meld.** Een vroegtijdige melding kan altijd aangevuld worden. Niet melden bij een meldingsplichtig incident kan leiden tot boetes tot **€10 miljoen of 2% van de wereldwijde jaaromzet**.

---

## Tijdlijn overzicht

```
T+0          T+24u              T+72u                T+1 maand
│            │                  │                    │
▼            ▼                  ▼                    ▼
Detectie ──► Initiële melding ──► Gedetailleerde ──► Eindrapport
             aan CCB              melding + impact    root cause +
             (eerste signaal)     + maatregelen       preventie
```

---

## Fase 0 — Detectie & eerste beoordeling (T+0 → T+2u)

### Detectiebronnen Contoso

| Bron | Wat het detecteert | Azure resource |
|---|---|---|
| Defender for Cloud | CSPM-alerts, SQL MI anomalies, IDPS-hits | Alle resources |
| Azure Firewall IDPS | Signature-hits, C2-verkeer, port scans | fw-contoso-hub-001 |
| Log Analytics KQL | Verdachte SQL-queries, anomale logins | law-contoso-mgmt |
| Azure Monitor alerts | Latency spikes, 5xx-pieken, CPU-pieken | web-contoso-prd, api-contoso-prd |
| Application Insights | Afwijkende foutcijfers, distributed traces | fn-contoso-prd-001 |
| Entra ID / PIM-logs | Ongeautoriseerde PIM-activatie, impossible travel | Entra ID tenant |
| Key Vault audit log | Ongeautoriseerde secret-toegang | kv-contoso-prd |
| NSG flow logs | Verdacht lateraal verkeer tussen subnetten | Alle NSGs |

### Ernst classificatie

| Klasse | Definitie | Voorbeelden | Actie |
|:---:|---|---|---|
| P1 | Kritisch — productiedienst volledig uitgevallen of data gecompromitteerd | Ransomware, SQL MI-diefstal, website neer | Onmiddellijke escalatie CISO + NIS2-melding |
| P2 | Hoog — gedeeltelijke verstoring of vermoeden van compromise | Verhoogd foutpercentage, verdachte logins | Escalatie binnen 2u, NIS2-melding evalueren |
| P3 | Medium — geen productie-impact, voorzorgsmaatregel | Policy-drift, verdachte scan | Behandelen in dagelijkse security review |

### Eerste beoordeling checklist

```
☐ Alert ontvangen in Defender for Cloud of Log Analytics
☐ Ernst classificeren (P1 / P2 / P3)
☐ Is er sprake van significante verstoring of aanvalsindicatoren?
☐ Bij P1/P2: CISO / management notificeren
☐ Incident response team samenstellen
☐ Begin tijdlijn documenteren (elke actie met timestamp)
☐ Bewijs veiligstellen (screenshots, log exports) — NIET wissen!
```

---

## Fase 1 — Initiële melding (24 uur)

**Wettelijke basis:** NIS2 Art. 23(1)
**Verantwoordelijke:** CISO of aangewezen NIS2-contactpersoon (team-cloud@contoso.be)
**Meldingskanaal:** https://ccb.belgium.be/nl/meld-een-incident

### Verplichte inhoud initiële melding

```
☐ Naam en contactgegevens: Contoso Manufacturing NV, team-cloud@contoso.be
☐ Datum en tijdstip van detectie (UTC)
☐ Korte beschrijving van het incident (type, eerste indicaties)
☐ Getroffen systemen of diensten (bv. web-contoso-prd, sql-contoso-prd-001)
☐ Eerste schatting van impact en getroffen gebruikers (max. 450)
☐ Of het incident grensoverschrijdend effect kan hebben (Luik/Hasselt sites)
☐ Huidige status: aan de gang / ingedamd / opgelost
```

### Interne acties parallel aan melding

```
☐ Directie op de hoogte stellen
☐ Juridische dienst informeren
☐ DPO informeren (GDPR Art. 33 — ook GBA binnen 72u bij persoonsgegevens)
☐ Getroffen systemen isoleren indien nodig (subnet-isolatie, firewall-blokkade)
☐ Bewijs veiligstellen — Log Analytics exports, NSG flow logs, Defender-alerts
```

> **Termijn:** De 24u-termijn geldt vanaf **detectie**, niet vanaf bevestiging van de omvang. Bij twijfel: meld en vul later aan.

---

## Fase 2 — Gedetailleerde melding (72 uur)

**Wettelijke basis:** NIS2 Art. 23(4)
**Verantwoordelijke:** Management + Tech Lead + SOC/Analyst

### Verplichte inhoud gedetailleerde melding

```
☐ Bijgewerkte beschrijving: aanvalstype, aanvalsvector, bevestigde scope
☐ Getroffen Azure-resources (bv. sql-contoso-prd-001, kv-contoso-prd, snet-spoke-data)
☐ Volledige tijdlijn: detectie → inperking → eerste herstel
☐ Impactbeoordeling per systeem (CIA-triád: Confidentiality / Integrity / Availability)
☐ Aantal getroffen gebruikers en/of klanten
☐ Reeds genomen inperkingsmaatregelen
☐ Indicatie of persoonsgegevens betrokken zijn
☐ Verwachte hersteldatum
```

### Technische forensische analyse — Contoso KQL-queries

**Verdachte activiteit op SQL MI:**
```kql
AzureDiagnostics
| where Category == "SQLSecurityAuditEvents"
| where TimeGenerated between (datetime(T-2h) .. datetime(T+24h))
| where action_name_s !in ("SELECT", "INSERT", "UPDATE", "DELETE")
| project TimeGenerated, action_name_s, server_principal_name_s,
          database_principal_name_s, statement_s
| order by TimeGenerated asc
```

**Ongeautoriseerde Key Vault toegang:**
```kql
AzureDiagnostics
| where ResourceType == "VAULTS" and Category == "AuditEvent"
| where ResultType != "Success"
| project TimeGenerated, OperationName, CallerIPAddress,
          identity_claim_oid_g, ResultDescription
```

**Verdacht netwerkverkeer (NSG flow logs):**
```kql
AzureNetworkAnalytics_CL
| where TimeGenerated > ago(24h)
| where FlowStatus_s == "A" and AllowedInFlows_d > 1000
| summarize TotalFlows=sum(AllowedInFlows_d) by SrcIP_s, DestPort_d
| order by TotalFlows desc
| take 20
```

**PIM-activaties buiten kantooruren:**
```kql
AuditLogs
| where OperationName == "Add eligible member to role"
    or OperationName == "Activate eligible assignment"
| where TimeGenerated > ago(72h)
| extend Hour = datetime_part("hour", TimeGenerated)
| where Hour < 7 or Hour > 19
| project TimeGenerated, OperationName, InitiatedBy, TargetResources
```

---

## Fase 3 — Eindrapport (1 maand)

**Wettelijke basis:** NIS2 Art. 23(7)
**Verantwoordelijke:** Tech Lead + SOC/Analyst + Management

### Verplichte inhoud eindrapport

```
☐ Volledige root cause analyse (5-whys of fishbone-methode)
☐ Gedetailleerde tijdlijn van het incident (begin tot volledig herstel)
☐ Definitieve impactbeoordeling — CIA-triád per betrokken systeem
☐ Bewijs van volledig herstel en integriteitsverificatie van systemen
☐ Overzicht preventieve maatregelen die zijn of worden getroffen
☐ Lessons learned + aanpassing incidentresponseplan
☐ Aanpassingen aan Azure Policy, NSG-regels of Firewall-ruleset
☐ Plan voor tabletop exercise binnen 3 maanden
```

### Preventieve maatregelen na incident (Contoso-context)

| Actie | Verantwoordelijke | Tool / Locatie |
|---|---|---|
| Nieuwe Deny-policy deployen | Cloud Platform Engineer | `04-security/policies/` + Bicep-pipeline |
| NSG-regel toevoegen op aanvalsvector | Tech Lead | `nsg-regels.xlsx` + ARM/Bicep |
| Firewall IDPS-signature activeren | SOC/Analyst | Azure Firewall Policy — IDPS tab |
| Secrets roteren in Key Vault | Tech Lead | kv-contoso-prd — lifecycle policy |
| PIM eligible assignments reviewen | Cloud Platform Engineer | Entra ID → PIM → Access Review |
| RBAC-audit uitvoeren | Cloud Platform Engineer | `rbac-assignments.json` bijwerken |
| Runbook bijwerken | SOC/Analyst | Automation Account + `README-security-governance.md` |
| Defender for Cloud aanbevelingen remediëren | SOC/Analyst | Defender → Recommendations |

---

## Interne escalatiepad

```
Detectie (alert in Defender / Monitor / Log Analytics)
    │
    ▼
SOC/Analyst: Ernst classificeren (P1/P2/P3)
    │
    ├─ P3: Behandelen in dagelijkse security review → geen NIS2-melding
    │
    └─ P1/P2:
         │
         ▼
    CISO / team-cloud@contoso.be notificeren (< 1u na detectie)
         │
         ▼
    Incident Response Team samenstellen
    (Network · App · Data · Security leads)
         │
         ▼
    ┌────┴────────────────────────────────────────┐
    │                                             │
    ▼                                             ▼
Technisch (Tech Lead)                   Compliance (Management)
- Systemen isoleren                     - CCB melding T+24u
- Forensisch onderzoek                  - DPO informeren
- Logs veiligstellen                    - GBA indien persoonsgegevens
- Patch / mitigatie                     - Directie briefing
    │                                             │
    └────────────┬────────────────────────────────┘
                 │
                 ▼
         Gedetailleerde melding CCB T+72u
                 │
                 ▼
         Eindrapport + preventie T+1 maand
```

---

## GDPR koppeling (Art. 33)

Als bij het incident **persoonsgegevens** betrokken zijn (gebruikersdata, SAP ERP-data, productiedata met persoonlijke informatie), geldt naast NIS2 ook de GDPR-meldingsplicht:

| Actie | Termijn | Ontvanger |
|---|---|---|
| Intern melden aan DPO | Direct bij detectie | dpo@contoso.be |
| Melding aan GBA | Binnen 72 uur | www.gegevensbeschermingsautoriteit.be |
| Betrokkenen informeren | Indien hoog risico — zo snel mogelijk | Getroffen gebruikers/medewerkers |

> De 72u-termijn voor GBA-melding loopt **parallel** aan de NIS2-termijnen, niet na afloop.

---

## Referenties

- [NIS2-wet België (Belgisch Staatsblad)](https://www.ejustice.just.fgov.be)
- [CCB — Meld een incident](https://ccb.belgium.be/nl/meld-een-incident)
- [NIS2-richtlijn Art. 23 — Meldingsverplichtingen](https://eur-lex.europa.eu/legal-content/NL/TXT/?uri=CELEX%3A32022L2555)
- [GBA — Melding datalek](https://www.gegevensbeschermingsautoriteit.be/burger/themas/datalek-melden)
- [ENISA — Good practices for incident response](https://www.enisa.europa.eu/topics/incident-response)

---

*Versie 1.0 · team-cloud@contoso.be · West Europe 2025 · INTERN — vertrouwelijk*


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
