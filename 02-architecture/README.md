# 02 — architectuurdiagrammen

> **Deliverable**: Platform Landing Zone + Application Landing Zone diagram  
> **Gewicht**: 20% van de totale eindopdrachtscore

---

## opdracht

Ontwerp de volledige Azure-architectuur voor de gemigreerde Contoso-applicatie. Je levert **twee diagrammen** op:

1. **Platform Landing Zone** — de organisatorische en governance structuur (Management Groups, Subscriptions, Policies, identity)
2. **Application Landing Zone** — de eigenlijke workload in de spoke subscription

---

## deel A: platform landing zone

### wat is een platform landing zone?

Een **Platform Landing Zone** is de funderende infrastructuur die alle workloads ondersteunt. Ze bestaat uit gedeelde services (hub networking, identity, monitoring) en de governance-structuur die consistentie afdwingt over alle subscriptions.

### structuur
<img width="2184" height="2268" alt="image" src="https://github.com/user-attachments/assets/f6cfedbe-4b0c-40e0-857a-bc080282228f" />

Tenant Root Group
└── Contoso Manufacturing (MG)
    ├── Platform (MG)
    └── Landing Zones (MG)
        └── Corp (MG)
            ├── Contoso-Prod (Subscription)
            └── Contoso-NonProd (Subscription)
```
Tenant Root Group
Wat zit hierin?
De volledige Entra ID / Azure AD tenant
Alle anagement groups en subscriptions hangen hieronder
De globale policies en governance regels ( bijvoorbeeld enkel recources toelaten in specifieke regio's, verplichte tagging, naming conventions, beperken van publieke IP en verplichten van private endpoints) 

Management Group 
Wat zit hierin?
Logische structuur boven de subscriptions
Het opsplitsen in:
Platform & Landing zones.

Met centraal beheerde policies en rolgebaseerde toegangsrechten (RBAC) kunnen beveilingingsregels en toegangsbeheer efficiënt worden toegepast over meerdere subscriptions tegelijk. Hierdoor onstaat een consistente en veilige beheerstructuur binnen de omgeving.
Daarnaast wordt een duidelijke scheiding aangebracht tussen het platform en de workloads:
Platform doet het beheer van netwerken, security, identity, monitoring en gedeelde services.
Workloads of applicaties: ontwikkeling, deployment en beheer van applicaties en bedrijfsomgevingen. 

Door die scheiding kan het platformteam focussen op een stabiele en veilige basis, terwijl applicatieteams flexibel kunnen ontwikkelen en beheren zonder elkaar in de weg te zitten.

Platform layer (gedeelde services)
Dit is de techtnische fundering waarop alles draait.

Hub VNet / Conectivity 
Wat zit hierin?
Heb VNet
Azure Firewall
VPN Gateway / ExpressRoute (Optioneel)
Azure Bastion
Private DNS

Alle traffic loopt via één gecontroleerd punt daardoor is er een betere security en logging.

Management
Wat zit hierin?
Azure moitor/ log analytics
backup services
automation accounts
update management

Door centrale monitoring krijg je een duidelijk beeld van wat er in het netwerk gebeurt. Problemen of afwijkingen worden sneller zichtbaar, waardoor je gerichter kan reageren.
Met geautomatiseerd beheer worden veel taken automatisch uitgevoerd, wat tijd bespaart en menselijke fouten vermindert.
Samen zorgt dit voor een snelle detectie van problemen en een vlotteren werking van het volledig systeem.

Idenitity
Wat zit hierin?
Entra ID (azure AD)
AD domain services/ Domain controllers
conditionl access policies

een centraal Identiry en access management (IAM) zorgt ervoor dat alle gebruikers en hun toegangsrechten op één plaats beheerd worden.
Met beveiligde login, zoals MFA en het zero Trust-principe, wordt er extra gecontroleerd wie toegang krijgt tot systemen en data. alleen wie echt geverifieerd is kan verder.


In een hybride setup wordt een Domain Controller replica in Azure gebruikt.  
Deze ondersteunt klassieke workloads (domain-joined VM’s, legacy applicaties) en zorgt voor integratie tussen on-premises Active Directory en Entra ID.

Landing zones (workloads)
Opgesplitst in:
Production
Non-Production (Dev/test)

Wat zit hierin?
Subscriptions per omgeving
Applicaties, databases, services.

Door de omgevingen van elkaar te isoleren, blijven ze volledig gescheiden en beïnvloeden ze elkaar niet.
Zo kan een fout of een wijziging in Dev geen impact hebben op de productieomgeving.
Ook maakt het met deze aanpak mogelijk om de kosten per omgeving op te volgen en beter te beheren.

Spoke VNets
Wat zit hierin?
Virtuele netwerken per workload.
Subnets voor verschillende componenten
    apps
    databases
    integraties

Netwerkisolatie per applicatie of omgeving zorgt ervoor dat systemen van elkaar gescheiden blijven en niet zomaar met elkaar kunnen communiceren. Dat beperkt de impact van fouten of beveiligingsincidenten.

Via peering blijven de verschillende netwerken toch verbonden met de centrale hub, zo is er wanneer nodig een gecontroleerde communicatie.
Al het verkeer loopt daarbij langs een firawall, waar het wordt gevilterd en gecontroleerd op veiligheid en toegestane toegang.

Private Entpoints
Wat zit hierin?
Private verbindingen naar de Paas services.
    SQL
    Storage
    Key Vault

Door geen publieke toegang toe te staan, worden systemen niet rechstreeks bereikbaar vanaf het internet. Dit verkleint meteen het risico op ongewenst toegang.
Alle verkeer blijft vinen het Azure-netwerk, waardoor het beter gecontroleerd en beveiligd kan worden via interne netwerkregels.
Het doe is een Zero Trust Netwerkbenadering, waarbij standaard niemand vertrouwd wordt en elke toegang expliciet gecontroleerd wordt.

Application gateway + Waf
Wat zit hierin?
Layer 7 load balancer
web application firewall (Waf)
SSL termination

een application gateway met SSL termination helpt om webverkeer veilig en efficiënt te verwerken. Het beschermt tegen veelvoorkomende aanvallen zoals SQL injection, XSS en andere webgebasseerde attacks door inkomend verkeer eerst te inspecteren en te filteren voordat het de backend bereikt. 

Azure front door
Wat zit hierin?
Globale entry point
CDN + Caching
Load balancing over regio's
DDoS bescherming.


Landing Zones MG
| Veld     | Waarde                                        |
| -------- | --------------------------------------------- |
| Naam     | Landing Zones                                 |
| Doel     | Overkoepelende MG voor workload subscriptions |
| Policies | Defender for Cloud verplicht                  |
|          | Network Watcher verplicht                     |
|          | Alleen goedgekeurde VM SKUs                   |
|          | Geen Classic resources                        |

Corp MG
| Veld     | Waarde                                    |
| -------- | ----------------------------------------- |
| Naam     | Corp                                      |
| Doel     | Governance voor interne bedrijfsworkloads |
| Policies | VNet integration verplicht                |
|          | Geen Public IPs                           |
|          | Private Endpoints verplicht               |
|          | Geen direct outbound internet             |

Laag 2 — Subscriptions

Connectivity Subscription
| Veld            | Waarde                                             |
| --------------- | -------------------------------------------------- |
| Naam            | Connectivity                                       |
| Doel            | Centrale netwerkdiensten                           |
| Resource groups | rg-hub-network · rg-firewall · rg-gateway · rg-dns |

Management Subscription
| Veld            | Waarde                                    |
| --------------- | ----------------------------------------- |
| Naam            | Management                                |
| Doel            | Monitoring, backup en automatisering      |
| Resource groups | rg-management · rg-backup · rg-automation |

Identity Subscription
| Veld            | Waarde                      |
| --------------- | --------------------------- |
| Naam            | Identity                    |
| Doel            | Hybride identiteitsdiensten |
| Resource groups | rg-identity · rg-adc        |

Contoso-Prod Subscription
| Veld             | Waarde                                    |
| ---------------- | ----------------------------------------- |
| Naam             | Contoso-Prod                              |
| Doel             | Productieworkloads                        |
| Resource groups  | rg-prod-app · rg-prod-db · rg-prod-shared |
| Management Group | Corp                                      |

Contoso-NonProd Subscription
| Veld             | Waarde                   |
| ---------------- | ------------------------ |
| Naam             | Contoso-NonProd          |
| Doel             | Dev/test/staging         |
| Extra            | Auto-shutdown om 20:00   |
| Resource groups  | rg-dev-app · rg-test-app |
| Management Group | Corp                     |

Laag 3 — Connectivity

Hub VNet
| Veld           | Waarde         |
| -------------- | -------------- |
| Naam           | Hub VNet       |
| CIDR           | 10.0.0.0/16    |
| Subscription   | Connectivity   |
| Resource group | rg-hub-network |
| Regio          | West Europe    |

Hub subnetten
| Subnet                        | CIDR         | Doel                       | NSG               |
| ----------------------------- | ------------ | -------------------------- | ----------------- |
| AzureFirewallSubnet           | 10.0.0.0/26  | Azure Firewall Premium     | Niet ondersteund  |
| AzureFirewallManagementSubnet | 10.0.0.64/26 | Firewall management NIC    | Niet ondersteund  |
| GatewaySubnet                 | 10.0.0.32/27 | VPN Gateway / ExpressRoute | Niet ondersteund  |
| AzureBastionSubnet            | 10.0.2.0/27  | Azure Bastion              | Vast Azure beleid |
| snet-hub-dns                  | 10.0.3.0/28  | DNS Private Resolver       | Ja                |
| snet-hub-mgmt                 | 10.0.4.0/28  | Management VMs             | Ja                |

Azure Firewall
| Veld           | Waarde                                               |
| -------------- | ---------------------------------------------------- |
| Naam           | fw-contoso-hub-001                                   |
| SKU            | Premium                                              |
| Private IP     | 10.0.0.4                                             |
| Features       | IDPS · TLS-inspectie · Threat Intel · FQDN-filtering |
| Doel           | Centraal egress-punt                                 |
| Resource group | rg-firewall                                          |

VPN Gateway

| Veld           | Waarde                   |
| -------------- | ------------------------ |
| Naam           | vpngw-contoso-hub-weu    |
| SKU            | VpnGw1 Generation2       |
| Type           | Route-based              |
| BGP            | Ingeschakeld (ASN 65000) |
| Active/Active  | Ja                       |
| Verbindingen   | Gent · Luik · Hasselt    |
| Resource group | rg-gateway               |

Azure Bastion
| Veld           | Waarde                |
| -------------- | --------------------- |
| SKU            | Basic                 |
| Doel           | Browser-based SSH/RDP |
| Resource group | rg-hub-network        |

DNS Private Resolver
| Veld             | Waarde                                |
| ---------------- | ------------------------------------- |
| Naam             | dnspr-contoso-hub-001                 |
| Subnet           | snet-hub-dns                          |
| Inbound endpoint | 10.0.3.4                              |
| Doel             | DNS-forwarding voor privatelink zones |

Private DNS Zones
| Zone                               | Doel                 |
| ---------------------------------- | -------------------- |
| privatelink.database.windows.net   | SQL Managed Instance |
| privatelink.blob.core.windows.net  | Storage Blob         |
| privatelink.file.core.windows.net  | Storage Files        |
| privatelink.vaultcore.azure.net    | Key Vault            |
| privatelink.servicebus.windows.net | Service Bus          |
| privatelink.azurewebsites.net      | App Service          |
| contoso.internal                   | Interne records      |

VNet Peerings
| Spoke          | CIDR         | Gateway transit |
| -------------- | ------------ | --------------- |
| Spoke-Prod     | 10.20.0.0/16 | Ja              |
| Spoke-NonProd  | 10.30.0.0/16 | Ja              |
| Spoke-Identity | 10.40.0.0/24 | Ja              |

UDR
| Route          | Next hop                |
| -------------- | ----------------------- |
| 0.0.0.0/0      | Azure Firewall 10.0.0.4 |
| 192.168.1.0/24 | Azure Firewall 10.0.0.4 |
| 192.168.2.0/24 | Azure Firewall 10.0.0.4 |
| 192.168.3.0/24 | Azure Firewall 10.0.0.4 |
| SqlManagement  | Internet                |

Laag 4 — Identity

Entra ID
| Veld     | Waarde                     |
| -------- | -------------------------- |
| Tenant   | contoso.onmicrosoft.com    |
| Type     | Hybride identiteit         |
| Licentie | Entra ID P1                |
| Doel     | Centrale identity provider |

Entra Connect Sync
| Veld            | Waarde                                       |
| --------------- | -------------------------------------------- |
| Methode         | Password Hash Sync                           |
| Sync interval   | 30 minuten                                   |
| Primaire server | vm-entraconnect-01                           |
| Staging server  | vm-entraconnect-02                           |
| Bron            | On-prem AD DS                                |
| Doel            | Synchronisatie van users, groepen en devices |

DC-replica in Azure

| Veld           | Waarde                              |
| -------------- | ----------------------------------- |
| VM namen       | vm-dc-01 · vm-dc-02                 |
| OS             | Windows Server 2022                 |
| Configuratie   | HA pair                             |
| Subnet         | 10.40.0.0/24                        |
| Doel           | Lokale authenticatie bij VPN-uitval |
| Resource group | rg-adc                              |

Conditional Access
| Beleid            | Configuratie                   |
| ----------------- | ------------------------------ |
| MFA               | Verplicht voor alle gebruikers |
| Compliant devices | Intune vereist                 |
| Legacy auth       | Geblokkeerd                    |
| Named locations   | Gent · Luik · Hasselt          |

PIM
| Veld          | Waarde                           |
| ------------- | -------------------------------- |
| Toegangstype  | Eligible assignments             |
| Activatieduur | Max 4 uur                        |
| Goedkeuring   | Verplicht voor Owner/Contributor |
| Audit         | Naar Log Analytics               |
| Doel          | Just-in-Time admin toegang       |

Azure Key Vault
| Veld           | Waarde                                       |
| -------------- | -------------------------------------------- |
| Naam           | kv-contoso-platform-001                      |
| Inhoud         | Secrets · certificaten · sleutels            |
| Features       | Soft-delete · purge protection · Managed HSM |
| Resource group | rg-identity                                  |

Laag 5 — Management

Log Analytics Workspace
| Veld              | Waarde                            |
| ----------------- | --------------------------------- |
| Naam              | law-contoso-mgmt-001              |
| Regio             | West Europe                       |
| Hot retention     | 90 dagen                          |
| Archive retention | 2 jaar                            |
| Scope             | Alle subscriptions                |
| Features          | KQL · Dashboards · Sentinel-ready |
| Resource group    | rg-management                     |

Azure Monitor
| Veld           | Waarde                                                 |
| -------------- | ------------------------------------------------------ |
| Alerts         | CPU · SQL storage · Backup failures · Firewall threats |
| Action groups  | Email · Teams webhook                                  |
| Features       | Metrics · Autoscale · Dashboards                       |
| Resource group | rg-management                                          |

Automation Account
| Veld           | Waarde                            |
| -------------- | --------------------------------- |
| Features       | Update Management · VM start/stop |
| Runbooks       | GitHub source control             |
| Taken          | Auto-shutdown · Bicep deployments |
| Resource group | rg-automation                     |

Recovery Services Vault
| Veld           | Waarde                            |
| -------------- | --------------------------------- |
| Naam           | rsv-contoso-mgmt-001              |
| Redundantie    | GRS                               |
| Retentie       | 30 dagen                          |
| Scope          | SQL MI · Azure Files · VM backups |
| Resource group | rg-backup                         |

Cost Management
| Veld          | Waarde                                 |
| ------------- | -------------------------------------- |
| Budget alerts | 80% waarschuwing · 100% actie          |
| Export        | Dagelijkse export naar Storage Account |
| Scope         | Per subscription + totaal              |

### diagram vereisten (Platform LZ)

Gebruik de officiële Azure-architectuuricoontjes. Neem minimaal op:

- [ ] Management Group hiërarchie
- [ ] Alle subscriptions (minimum 3: Connectivity, Management, Workload)
- [ ] Hub VNet met subnetten en Azure Firewall
- [ ] VPN Gateway of ExpressRoute naar on-prem
- [ ] Log Analytics Workspace (in Management subscription)
- [ ] Entra ID-koppeling (Entra Connect of Cloud Sync)
- [ ] Policy-toewijzingspunten (symbool of annotatie)

---

## deel B: application landing zone

### wat is een application landing zone?

De **Application Landing Zone** (ook "workload spoke" genoemd) is de subscription waar de eigenlijke applicatie leeft. Ze is verbonden met de platform landing zone via VNet peering naar de hub.

### doelarchitectuur (PaaS — Fase 2 Refactor)

De Contoso-applicatie wordt gemigreerd naar de volgende Azure PaaS-diensten:

| On-premises | Azure PaaS equivalent | Reden |
|---|---|---|
| IIS + ASP.NET WebForms | **Azure App Service** (Windows) | Managed hosting, auto-scale |
| .NET Windows Services | **Azure WebJobs** of **Azure Functions** | Serverless/managed background jobs |
| SQL Server Always On | **Azure SQL Database** (Business Critical) | Managed, HA ingebouwd, geo-replication |
| F5 BIG-IP | **Application Gateway + WAF v2** | Layer 7 load balancing, WAF |
| Active Directory auth | **Microsoft Entra ID + App registration** | Modern auth (OAuth2/OIDC) |
| NAS (UNC shares) | **Azure Files** of **Azure Blob Storage** | Managed file storage |
| SCOM monitoring | **Azure Monitor + Application Insights** | Cloud-native observability |
| Exchange SMTP | **Azure Communication Services** of **SendGrid** | Managed mail delivery |
| Veeam Backup | **Azure Backup + SQL LTR** | Integrated cloud backup |

### verwacht diagram (Application LZ)

```
┌─────────────────────────────────────────────────────────────────┐
│  Contoso-Prod Subscription  (Spoke VNet: 10.20.0.0/16)         │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Resource Group: rg-contoso-networking                   │   │
│  │  VNet Peering ──► Hub VNet (Connectivity Subscription)   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Resource Group: rg-contoso-frontend                     │   │
│  │                                                          │   │
│  │  [App Gateway + WAF v2]                                  │   │
│  │         │                                                │   │
│  │  [App Service Plan P2v3]                                 │   │
│  │    ├── [App Service: web-contoso-prd]                    │   │
│  │    └── [App Service: api-contoso-prd]                    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Resource Group: rg-contoso-compute                      │   │
│  │                                                          │   │
│  │  [Function App / WebJobs]                                │   │
│  │    ├── Scheduler Function                                │   │
│  │    ├── Processor Function                                │   │
│  │    └── Reporter Function                                 │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Resource Group: rg-contoso-data                         │   │
│  │                                                          │   │
│  │  [Azure SQL DB: Business Critical]                       │   │
│  │    └── Geo-replication ──► North Europe                  │   │
│  │  [Azure Storage Account] (Blob + Files)                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Resource Group: rg-contoso-security                     │   │
│  │                                                          │   │
│  │  [Key Vault]   [Managed Identity]   [Defender for Cloud] │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Resource Group: rg-contoso-monitoring                   │   │
│  │                                                          │   │
│  │  [Application Insights]  [Log Analytics Workspace]       │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### diagram vereisten (Application LZ)

Gebruik de officiële Azure-architectuuricoontjes. Neem minimaal op:

- [ ] Application Gateway + WAF v2
- [ ] App Service Plan + App Services (min. 2 slots: production + staging)
- [ ] Azure Functions of WebJobs
- [ ] Azure SQL Database + geo-replication pijl
- [ ] Azure Storage Account
- [ ] Key Vault (met pijlen naar App Services voor secret ophalen)
- [ ] Managed Identity (User Assigned of System Assigned)
- [ ] Private Endpoints voor SQL, Storage, Key Vault
- [ ] Application Insights
- [ ] Verbinding naar Hub via VNet Peering
- [ ] Verbinding naar on-prem (via Hub — VPN/ER)
- [ ] Deployment slots (staging ↔ production swap)

---

## architectuurbeslissingen (Architecture Decision Records)

Voor de volgende keuzes schrijf je een korte **ADR (Architecture Decision Record)**:

### ADR-001: App Service vs AKS vs Azure Container Apps

| | App Service | AKS | Container Apps |
|---|---|---|---|
| Complexiteit | Laag | Hoog | Middel |
| Beheer overhead | Minimaal | Hoog | Laag |
| Kost | Middel | Hoog | Laag-Middel |
| Geschikt voor WebForms migratie | ✅ | ⚠️ | ⚠️ |

**Vul in**: Welke kies jij en waarom?

### ADR-002: Azure SQL DB tier keuze

| Tier | vCores | Beschikbaarheid | Prijs |
|---|---|---|---|
| General Purpose | 4–80 | 99.99% (zone redundant) | € |
| Business Critical | 4–80 | 99.995% + read replica inbegrepen | €€€ |
| Hyperscale | 1–80 | Hoog, andere architectuur | €€ |

**Vul in**: Welke tier kies jij? Onderbouw met de RTO/RPO-vereisten.

### ADR-003: VPN Gateway vs ExpressRoute

| | VPN Gateway | ExpressRoute |
|---|---|---|
| Bandbreedte | Tot 10 Gbps | 50 Mbps – 100 Gbps |
| Latency | Variabel (internet) | Laag (dedicated circuit) |
| Kost | Laag (€140–€700/mnd) | Hoog (€500–€5000+/mnd) |
| Gebruik | Dev/test, lagere eisen | Productie, hoge eisen |

**Vul in**: Welke kies jij voor Contoso? Motiveer.

---

## Azure Well-Architected Framework check

Documenteer hoe je ontwerp scoort op de 5 pijlers van het Azure Well-Architected Framework:

| Pijler | Hoe wordt dit geadresseerd in je ontwerp? |
|---|---|
| **Reliability** | (bijv. zone-redundante App Service, geo-replica SQL, ...) |
| **Security** | (bijv. WAF, Private Endpoints, Managed Identity, ...) |
| **Cost Optimization** | (bijv. Reserved Instances, Auto-scale, Dev/Test subs, ...) |
| **Operational Excellence** | (bijv. CI/CD, IaC, monitoring, ...) |
| **Performance Efficiency** | (bijv. App Service auto-scale, SQL tier, CDN optioneel, ...) |

---

## wat je inlevert

```
02-architecture/
├── README.md                        ← dit bestand, volledig ingevuld
├── platform-landing-zone.png        ← diagram Platform LZ
├── application-landing-zone.png     ← diagram Application LZ
└── adr/
    ├── ADR-001-compute-keuze.md
    ├── ADR-002-database-tier.md
    └── ADR-003-connectivity.md
```

---

## beoordelingscriteria (20 punten)

| Criterium | Punten |
|---|---|
| Platform LZ diagram correct en volledig | 5 |
| Application LZ diagram correct en volledig | 7 |
| Azure-iconen correct gebruikt | 2 |
| ADR's aanwezig met onderbouwing | 4 |
| Well-Architected Framework check ingevuld | 2 |

---

_Ga verder naar [`../03-network/README.md`](../03-network/README.md)_

---
