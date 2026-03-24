# AVCloudEngineerEindopdracht
Eindopdracht voor de avondopleiding Cloud Engineer bij Syntra. Schooljaar 2025 - 2026

# 00 — context: bestaande on-premises omgeving

> **Contoso Manufacturing NV** | legacy applicatie analyse  
> Startpunt voor de migratieopdracht

---

## bedrijfscontext

Contoso Manufacturing NV is een Belgisch productiebedrijf (≈ 450 medewerkers, 3 vestigingen: Gent, Luik, Hasselt) dat een interne **productieplannings- en rapportageapplicatie** beheert. De applicatie wordt dagelijks gebruikt door:

- Productiemedewerkers (order tracking, planning)
- Management (dashboards, KPI-rapportage)
- IT-afdeling (beheer, integraties met ERP)

De applicatie communiceert via REST API's met een extern SAP-systeem en verstuurt nachtelijks automatische rapporten via SMTP.

---

## technische omschrijving huidige omgeving

### servers & rollen

| Server | OS | Rol | CPU/RAM | Status |
|---|---|---|---|---|
| `WEB01` | Windows Server 2012 R2 | IIS 8.5 — Web frontend | 4 vCPU / 16 GB | EOL |
| `WEB02` | Windows Server 2012 R2 | IIS 8.5 — Web frontend | 4 vCPU / 16 GB | EOL |
| `APP01` | Windows Server 2012 R2 | .NET Windows Services | 8 vCPU / 32 GB | EOL |
| `APP02` | Windows Server 2012 R2 | .NET Windows Services | 8 vCPU / 32 GB | EOL |
| `SQL01` | Windows Server 2012 R2 | SQL Server 2014 (primary) | 16 vCPU / 64 GB | End-of-Support |
| `SQL02` | Windows Server 2012 R2 | SQL Server 2014 (secondary) | 16 vCPU / 64 GB | End-of-Support |
| `DC01` | Windows Server 2016 | Active Directory Domain Controller | 4 vCPU / 8 GB | In gebruik |
| `SCOM01` | Windows Server 2016 | SCOM 2012 monitoring | 4 vCPU / 16 GB | Verouderd |
| `BACKUP01` | Windows Server 2019 | Veeam Backup & Replication | 4 vCPU / 8 GB | In gebruik |

### netwerk

| Component | Details |
|---|---|
| Interne range | `10.10.0.0/16` |
| DMZ | `10.10.1.0/24` (F5 load balancer, reverse proxy) |
| App subnet | `10.10.2.0/24` |
| DB subnet | `10.10.3.0/24` |
| Mgmt subnet | `10.10.4.0/24` |
| Internet toegang | Via F5 BIG-IP (EOL 2025) |
| WAN (vestigingen) | MPLS verbindingen (provider: Proximus) |
| Firewall | Fortinet FortiGate (enkel perimeter) |

### storage & backup

| Component | Details |
|---|---|
| Primaire opslag | SAN (iSCSI), 20 TB gebruikt |
| Backup storage | NAS (lokaal, geen offsite) |
| Backup venster | Nachtelijk, 23u–03u |
| RTO | ≈ 4–6 uur (niet formeel gedocumenteerd) |
| RPO | 24 uur (daily backup) |

### applicatie stack

| Laag | Technologie | Opmerkingen |
|---|---|---|
| Frontend | ASP.NET WebForms 4.7 | Geen API-laag, monolithisch |
| Business logic | .NET Windows Services | 3 services (scheduler, processor, reporter) |
| Database | SQL Server 2014 (Always On, 2 nodes) | 1 database, ≈ 500 GB |
| Authenticatie | Windows Integrated Auth (Kerberos) | Gekoppeld aan on-prem AD |
| File storage | UNC shares op NAS | Rapporten, uploads |
| Externe integraties | SAP (REST/SOAP over MPLS) | Nachtelijke batch |
| Mail | SMTP relay (Exchange on-prem) | Uitgaande rapporten |

---

## diagram: bestaande on-premises architectuur

```
╔══════════════════════════════════════════════════════════════════════════════════════╗
║                        CONTOSO MANUFACTURING NV — ON-PREMISES                      ║
╚══════════════════════════════════════════════════════════════════════════════════════╝

  INTERNET
     │
     ▼
┌─────────────────────────────────────┐
│  DMZ  (10.10.1.0/24)                │
│                                     │
│   ┌──────────────────────────┐      │
│   │  F5 BIG-IP Load Balancer │ ◄────┼── HTTPS (443) van internet
│   │  (Hardware, EOL 2025)    │      │
│   └──────────┬───────────────┘      │
│              │                      │
│   ┌──────────▼───────────────┐      │
│   │  FortiGate Firewall       │      │
│   │  (Perimeter)              │      │
└───┴──────────┬────────────────┴──────┘
               │
               ▼
┌──────────────────────────────────────────────────────────────────────┐
│  WEB TIER  (10.10.2.0/24)                                            │
│                                                                      │
│   ┌─────────────────────┐    ┌─────────────────────┐                │
│   │  WEB01              │    │  WEB02              │                │
│   │  IIS 8.5            │    │  IIS 8.5            │                │
│   │  ASP.NET 4.7        │    │  ASP.NET 4.7        │                │
│   │  Windows Srv 2012R2 │    │  Windows Srv 2012R2 │                │
│   │  ⚠️  EOL             │    │  ⚠️  EOL             │                │
│   └──────────┬──────────┘    └──────────┬──────────┘                │
└──────────────┼───────────────────────────┼───────────────────────────┘
               │                           │
               ▼                           ▼
┌──────────────────────────────────────────────────────────────────────┐
│  APP TIER  (10.10.2.0/24)                                            │
│                                                                      │
│   ┌─────────────────────────────────────────────────────────┐       │
│   │  APP01 & APP02  (Windows Server 2012 R2  ⚠️  EOL)        │       │
│   │                                                         │       │
│   │   [.NET Service: Scheduler]  [.NET Service: Processor]  │       │
│   │   [.NET Service: Reporter]                              │       │
│   │                                                         │       │
│   │   UNC Share ──► \\NAS01\rapporten                       │       │
│   └──────────────────────────┬──────────────────────────────┘       │
└─────────────────────────────┼────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│  DATABASE TIER  (10.10.3.0/24)                                       │
│                                                                      │
│   ┌──────────────────────────────────────────────────────────┐      │
│   │         SQL Server 2014  Always On Availability Group    │      │
│   │                                                          │      │
│   │   ┌────────────────┐       ┌────────────────┐           │      │
│   │   │  SQL01         │◄─────►│  SQL02         │           │      │
│   │   │  PRIMARY       │       │  SECONDARY     │           │      │
│   │   │  16vCPU/64GB   │       │  16vCPU/64GB   │           │      │
│   │   │  ⚠️  EoS        │       │  ⚠️  EoS        │           │      │
│   │   └────────────────┘       └────────────────┘           │      │
│   │                DB size: ≈ 500 GB                         │      │
│   └──────────────────────────────────────────────────────────┘      │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│  MANAGEMENT  (10.10.4.0/24)                                          │
│                                                                      │
│  ┌───────────┐  ┌───────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  DC01     │  │  SCOM01   │  │  BACKUP01    │  │  NAS01       │  │
│  │  AD DS    │  │  Monitor  │  │  Veeam       │  │  UNC Shares  │  │
│  │  DNS/GPO  │  │  ⚠️  EOL   │  │  (lokaal)    │  │  (storage)   │  │
│  └───────────┘  └───────────┘  └──────────────┘  └──────────────┘  │
└──────────────────────────────────────────────────────────────────────┘

                              │ MPLS (Proximus)
                    ┌─────────┼──────────┐
                    ▼         ▼          ▼
               ┌────────┐ ┌───────┐ ┌─────────┐
               │ Gent   │ │ Luik  │ │ Hasselt │
               │ (HQ)   │ │       │ │         │
               └────────┘ └───────┘ └─────────┘

               Externe integraties:
               ┌───────────────────────────────┐
               │  SAP (REST/SOAP via MPLS)     │
               │  Exchange SMTP relay          │
               └───────────────────────────────┘

⚠️  = End-of-Life / End-of-Support component
```

---

## pijnpunten & risico's

| Pijnpunt | Impact | Prioriteit |
|---|---|---|
| Windows Server 2012 R2 — geen security patches | Hoog security risico | 🔴 Kritiek |
| SQL Server 2014 — geen support | Compliance + security risico | 🔴 Kritiek |
| F5 BIG-IP hardware EOL 2025 | Single point of failure | 🔴 Kritiek |
| SCOM 2012 — geen ondersteuning | Blind monitoring | 🟠 Hoog |
| Backup enkel lokaal (geen offsite) | RPO/RTO niet gegarandeerd | 🟠 Hoog |
| Monolithische ASP.NET WebForms | Moeilijk schaalbaar | 🟡 Middel |
| Kerberos auth — gebonden aan on-prem AD | Geen remote/cloud access | 🟡 Middel |
| MPLS WAN-kosten (3 vestigingen) | Hoge operationele kost | 🟡 Middel |

---

## migratiedoelstellingen

Op basis van bovenstaande analyse zijn de volgende doelstellingen geformuleerd:

1. **Security**: Alle workloads draaien op ondersteunde, gepatchte platformen
2. **Beschikbaarheid**: SLA ≥ 99,9% (≈ max 8,7 uur downtime per jaar)
3. **Schaalbaarheid**: Automatisch schalen bij piekbelasting (productieplanningsperiodes)
4. **DR/BC**: RTO ≤ 1 uur, RPO ≤ 15 minuten
5. **Kostoptimalisatie**: TCO-reductie van min. 20% over 3 jaar t.o.v. on-prem verlenging
6. **Compliance**: NIS2-ready architectuur (Belgische wetgeving)
7. **Observability**: Volledige monitoring stack (Application Insights, Log Analytics)

---

## migratiestrategie: Rehost → Refactor

De aanbevolen strategie is een **twee-fasen aanpak**:

| Fase | Strategie | Tijdlijn | Scope |
|---|---|---|---|
| Fase 1 | **Rehost** (Lift & Shift) | Maand 1–3 | VMs in Azure, SQL Managed Instance |
| Fase 2 | **Refactor** (PaaS modernisatie) | Maand 4–9 | App Service, Azure SQL Database |

> ⚠️ **Let op**: Voor de eindopdracht ontwerpen jullie de **Fase 2 (Refactor) architectuur** — de eindbestemming in PaaS.

_Ga verder naar [`../01-pricing/README.md`](../01-pricing/README.md)_