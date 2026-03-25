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

### verwachte structuur

Teken het volgende hiërarchisch diagram:

```
Tenant Root Group
└── Contoso Manufacturing (Management Group)
    ├── Platform (Management Group)
    │   ├── Identity Subscription
    │   │   └── Hub VNet, DC-replica, Entra Connect
    │   ├── Management Subscription
    │   │   └── Log Analytics, Automation, Backup Vault
    │   └── Connectivity Subscription
    │       └── Hub VNet, Firewall, VPN/ExpressRoute, DNS
    └── Landing Zones (Management Group)
        ├── Corp (Management Group)
        │   ├── Contoso-Prod Subscription
        │   └── Contoso-NonProd Subscription
        └── Online (Management Group — optioneel)
```

### te documenteren per laag

| Laag | Wat documenteer je? |
|---|---|
| Management Groups | Naam, doel, welke policies worden hier toegewezen |
| Subscriptions | Naam, doel, resource group structuur |
| Connectivity | Hub VNet CIDR, Firewall, Gateway type |
| Identity | Entra ID (Azure AD) tenant, Entra Connect sync, Conditional Access |
| Management | Log Analytics workspace, Automation Account, Backup |

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