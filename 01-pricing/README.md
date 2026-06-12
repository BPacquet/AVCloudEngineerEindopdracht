# 01 — azure prijsinschatting

> **Deliverable**: Azure-kostenraming + 3-jaar TCO-vergelijking  
> **Gewicht**: 20% van de totale eindopdrachtscore

---

## opdracht

Maak een volledige **Azure-prijsinschatting** voor de gemigreerde Contoso Manufacturing-applicatie. Je inschatting moet zowel de **maandelijkse Azure-kost** als een **3-jaar TCO-vergelijking** bevatten.

---

## vereisten

### ✅ Verplicht op te nemen

- [ ] Alle Azure resources die je in de architectuur hebt gedefinieerd (zie `../02-architecture/`)
- [ ] Maandelijkse kostentabel per resource
- [ ] Subtotalen per categorie (compute, netwerk, opslag, monitoring, ...)
- [ ] 3-jaar TCO: on-premises (verlengingskosten) vs Azure
- [ ] Onderbouwing van elke SKU-keuze
- [ ] **Azure Hybrid Benefit** toegepast waar relevant
- [ ] **Reserved Instances (1 jaar)** berekening als alternatief voor Pay-as-you-go
- [ ] Dev/Test omgevingen meegenomen (lagere kost via Dev/Test subscriptions)
- [ ] Excel-bijlage (`pricing-estimate.xlsx`) als bronbestand

---


## 3-jaar TCO vergelijking

### on-premises verlengingskosten (referentiescenario)

Bereken wat het zou kosten om de huidige on-prem omgeving te renoveren. Gebruik onderstaande indicatieve bedragen als basis (pas aan en onderbouw):

| Component | Eenmalige kost (schatting) | Jaarlijkse kost (schatting) |
|---|---|---|
| Hardware vervanging (servers × 9) | € 180.000 | € 18.000 (onderhoud) |
| Windows Server 2022 licenties | € 25.000 | — |
| SQL Server 2022 licenties | € 60.000 | — |
| F5 vervanging (load balancer) | € 35.000 | € 5.000 |
| Netwerkapparatuur refresh | € 20.000 | € 3.000 |
| Datacenter hosting (co-lo of on-prem) | — | € 30.000/jaar |
| IT-beheer (FTE, deels) | — | € 40.000/jaar |
| **Totaal** | **≈ € 320.000** | **≈ € 96.000/jaar** |

> ⚠️ Dit zijn voorbeeldcijfers. Gebruik deze als startpunt en pas aan op basis van je eigen research.

### verwachte structuur TCO-tabel

```
                  Jaar 1      Jaar 2      Jaar 3      TOTAAL 3J
────────────────────────────────────────────────────────────────
ON-PREMISES
  Capex             €320.000        €0          €0     €320.000
  Opex/jaar          €96.000    €96.000     €96.000    €288.000
  Subtotaal         €416.000    €96.000     €96.000    €608.000

AZURE (Pay-as-you-go)
  Maandkost × 12     €X.XXX      €X.XXX      €X.XXX
  Subtotaal          €X.XXX      €X.XXX      €X.XXX    €XX.XXX

AZURE (Reserved 1J, AHB)
  Subtotaal          €X.XXX      €X.XXX      €X.XXX    €XX.XXX

BESPARING (Azure vs On-prem)                            €XX.XXX (XX%)
────────────────────────────────────────────────────────────────
```


## wat je inlevert

```
01-pricing/
├── README.md              ← dit bestand, volledig ingevuld
└── pricing-estimate.xlsx  ← Excel met alle berekeningen
```

### inhoud README (volledig ingevuld)

1. **Aannames** — gedocumenteerde uitgangspunten
2. **Resource overzicht** — tabel met elke resource, SKU, prijs/maand
3. **Maandelijks kostenoverzicht** — gegroepeerd per categorie
4. **3-jaar TCO tabel** — vergelijking on-prem vs Azure
5. **Optimalisatieadvies** — Reserved Instances, AHB, Auto-scale
6. **Risico's** — onzekerheden in de inschatting

---

## beoordelingscriteria (20 punten)

| Criterium | Punten |
|---|---|
| Alle vereiste resources aanwezig en geraamd | 5 |
| Correcte SKU-keuzes met onderbouwing | 4 |
| 3-jaar TCO vergelijking correct uitgewerkt | 4 |
| Azure Hybrid Benefit correct toegepast | 3 |
| Aannames duidelijk gedocumenteerd | 2 |
| Optimalisatieadvies (Reserved Instances, ...) | 2 |

---

_Ga verder naar [`../02-architecture/README.md`](../02-architecture/README.md)_

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------AANVULLING BJORN PACQUET ---------------------------------------------------------------------------------------------
# Contoso Manufacturing — Azure Prijsinschatting

> **Regio:** West Europe (primair) · North Europe (DR)
> **Prijspeil:** Azure Pricing Calculator 2025 · **Versie:** 1.0
> **Auteur:** team-cloud@contoso.be · **Kader:** NIS2 · GDPR · ALZ v2

Alle bedragen zijn exclusief BTW. Blauw gemarkeerde cellen in de Excel-bijlagen zijn invoerparameters — wijzigingen herberekenen de TCO automatisch.

**Bijlagen:**
- `pricing-estimate.xlsx` — maandelijkse kosten + TCO-vergelijking
- `inventaris_resources.xlsx` — resource inventaris

---

## Inhoudsopgave

1. [Aannames](#1-aannames)
2. [Resource overzicht](#2-resource-overzicht)
3. [Maandelijks kostenoverzicht](#3-maandelijks-kostenoverzicht)
4. [3-jaar TCO vergelijking](#4-3-jaar-tco-vergelijking)
5. [Optimalisatieadvies](#5-optimalisatieadvies)
6. [Risico's](#6-risicos)

---

## 1. Aannames

Alle prijsberekeningen zijn gebaseerd op onderstaande aannames. Elke aanname is traceerbaar naar een bron of onderbouwing.

### 1.1 Gebruikers

| Parameter | Waarde | Onderbouwing |
|---|---|---|
| Totaal gebruikers | **450** | Gent 250 + Luik 100 + Hasselt 100 (opgave) |
| Gelijktijdige gebruikers — piek | **120 (27%)** | Industrienorm voor ERP/MES-applicaties: 25–30% van totaal |
| Gelijktijdige gebruikers — gemiddeld | **60 (13%)** | Kantooruren, 3 sites in dezelfde tijdzone |
| Piekuren per dag | 08:00–10:00 en 13:00–15:00 | Typisch voor productiebedrijf: ochtend- en namiddagshift |
| Sessieduur (gemiddeld) | 45 minuten | Schatting op basis van ERP-gebruikspatronen |

### 1.2 Compute & CPU-gebruik

| Parameter | Waarde | Onderbouwing |
|---|---|---|
| App Service SKU | **P2v3 (2 vCPU, 8 GB)** | Min. voor .NET Framework + auto-scale + staging slot |
| Min. instanties (HA) | **2** | ALZ-vereiste: geen single point of failure op App-laag |
| Max. instanties (auto-scale) | **6** | 120 gelijktijdige gebruikers bij 20 per instantie |
| Gemiddeld CPU-gebruik | **45%** | Typisch voor ASP.NET WebForms OLTP |
| Piek CPU-gebruik | **75–80%** | Auto-scale trigger bij > 70% gedurende 5 min |
| Azure Functions uitvoeringen/mnd | ~1.000.000 | Scheduler (dagelijks), Processor (per order), Reporter (wekelijks) |
| DC Replica VM-type | Standard_B2ms | Microsoft aanbeveling voor AD DS in Azure — 8 GB RAM minimum |

### 1.3 Database

| Parameter | Waarde | Onderbouwing |
|---|---|---|
| SQL MI SKU | **General Purpose 8 vCore** | Benchmark: 6–8 vCore nodig bij maandafsluiting (OLTP + batch) |
| Huidige database grootte | **280 GB** | Gemeten op productie SQL Server 2014 (incl. logs) |
| Verwachte jaarlijkse DB-groei | **15% per jaar** | Historisch gemiddelde op basis van 3 jaar groeidata |
| DB-grootte jaar 1 / 2 / 3 | 322 / 370 / 426 GB | 280 GB × 1,15ⁿ — blijft binnen 1 TB incl. in GP-tier |
| Backup PITR-retentie | **35 dagen** | ALZ v2 vereiste — standaard SQL MI max |
| LTR retentie | 4 weken / 12 maanden / 3 jaar | Recovery Services Vault retentiebeleid |
| Geo-replica (DR) | **North Europe** | Auto-failover group: RPO < 5s, RTO < 30s |

### 1.4 Netwerk & datatransfer

| Parameter | Waarde | Onderbouwing |
|---|---|---|
| Egress dataverkeer (extern) | **500 GB/mnd** | Rapporten + API-responses. Eerste 5 GB gratis. |
| Ingress dataverkeer | Gratis | Azure rekent geen kosten voor inkomend verkeer |
| VNet Peering Hub↔Prod | ~200 GB/mnd | App Service ↔ SQL MI via Private Endpoint + management |
| VNet Peering Hub↔NonProd | ~50 GB/mnd | Dev/test verkeer |
| VPN bandbreedte (gemiddeld) | 50 Mbps | S2S naar 3 sites: sync, AD-replicatie, SAP-integratie |
| VPN bandbreedte (piek) | 200 Mbps | Nachtelijke DB-synchronisatie + backup-verkeer |
| AGW Capacity Units | 10 CU | 120 gelijktijdige verbindingen + SSL-offload |

### 1.5 Opslag

| Parameter | Waarde | Onderbouwing |
|---|---|---|
| Blob storage — initieel volume | **2 TB** | Rapporten (5 jaar archief) + document-uploads + exports |
| Jaarlijkse groei blob storage | **20% per jaar** | Groeiend rapport-volume + nieuwe functionaliteit |
| Storage replicatie | **ZRS (Zone-Redundant)** | ALZ-vereiste productie — beschermt tegen AZ-storing |
| Storage tier | Hot tier | Rapporten dagelijks geraadpleegd — Cool tier niet efficiënt |
| Azure Files (NAS-vervanging) | 500 GB LRS | UNC shares — SMB 3.0, geen applicatiewijziging nodig |

### 1.6 Monitoring & logging

| Parameter | Waarde | Onderbouwing |
|---|---|---|
| Log Analytics — ingestie/dag | **8 GB/dag** | 31 resources × gemiddeld 0,26 GB/dag |
| Log Analytics — hot retentie | **90 dagen** | Incident response window |
| Log Analytics — archief | 2 jaar (Basic tier) | NIS2 Art. 21 — auditlogging aanbeveling 2 jaar |
| Application Insights — data/mnd | 5 GB/mnd | APM traces + dependencies + exceptions |

### 1.7 Azure Hybrid Benefit

Contoso beschikt over actieve Software Assurance-licenties:

| Licentie | Toepassing | AHB-korting |
|---|---|---|
| Windows Server Datacenter SA | App Service P2v3 (Windows) + DC-replica VMs | ~18% (App Service) / ~40% (VMs) |
| SQL Server Enterprise SA | SQL MI GP — Prod + DR-replica | ~40% op licentiedeel |

> **Let op:** AHB is niet automatisch — activeer via Bicep (`licenseType: Windows_Server`) of Azure Portal. Controleer SA-vervaldatum via [VLSC](https://www.microsoft.com/licensing/servicecenter).

---

## 2. Resource overzicht

Alle 31 resources uit de Platform Landing Zone en Application Platform. Prijzen zijn PAYG (Pay-as-you-go), West Europe, 2025.

### Netwerk

| Resource | SKU / Configuratie | Prijs/mnd | Prijs/jaar |
|---|---|---:|---:|
| Azure Firewall Premium | Premium · IDPS · TLS-inspectie | € 912 | € 10.944 |
| Application Gateway WAF v2 | WAF_v2 · 1 inst. · 10 CU · SSL-offload | € 365 | € 4.380 |
| VPN Gateway VpnGw2 | Route-based · BGP · IKEv2 · S2S × 3 | € 268 | € 3.216 |
| Azure Bastion Basic | Basic tier · SSH/RDP via browser | € 139 | € 1.668 |
| Public IP (pip-agw-prd) | Standard SKU · static | € 4 | € 48 |
| Egress bandbreedte | ~500 GB/mnd · €0,087/GB | € 43 | € 516 |
| VNet Peering | Hub↔Prod + Hub↔NonProd | € 3 | € 36 |
| **Subtotaal Netwerk** | | **€ 1.734** | **€ 20.808** |

### Compute

| Resource | SKU / Configuratie | Prijs/mnd | Prijs/jaar |
|---|---|---:|---:|
| App Service P2v3 — Web | P2v3 · 2 vCPU · 8 GB · Windows · 2 inst. | € 617 | € 7.404 |
| App Service P2v3 — API | P2v3 · 2 vCPU · 8 GB · Windows · 2 inst. | € 617 | € 7.404 |
| Azure Functions — Consumption | Consumption · VNet Integration | € 2 | € 24 |
| DC Replica vm-dc-01 | Standard_B2ms · Windows Server 2022 | € 70 | € 840 |
| DC Replica vm-dc-02 | Standard_B2ms · Windows Server 2022 | € 70 | € 840 |
| **Subtotaal Compute** | | **€ 1.376** | **€ 16.512** |

### Database

| Resource | SKU / Configuratie | Prijs/mnd | Prijs/jaar |
|---|---|---:|---:|
| SQL MI — General Purpose (Prod) | GP · 8 vCore · 1 TB incl. · West Europe | € 1.456 | € 17.472 |
| SQL MI — Geo-replica (DR) | GP · 8 vCore · North Europe · auto-failover | € 1.456 | € 17.472 |
| **Subtotaal Database** | | **€ 2.912** | **€ 34.944** |

### Storage

| Resource | SKU / Configuratie | Prijs/mnd | Prijs/jaar |
|---|---|---:|---:|
| Storage Account Blob ZRS | ZRS · Hot tier · 2 TB | € 40 | € 480 |
| Azure Files (SMB) | LRS · 500 GB · SMB 3.0 | € 30 | € 360 |
| Recovery Services Vault | GRS · SQL LTR 7d/4w/12m · VM backup | € 48 | € 576 |
| **Subtotaal Storage** | | **€ 118** | **€ 1.416** |

### Identiteit

| Resource | SKU / Configuratie | Prijs/mnd | Prijs/jaar |
|---|---|---:|---:|
| Microsoft Entra ID P1 | P1 · 450 gebruikers · MFA + CA + PIM | € 2.700 | € 32.400 |
| Entra Connect Sync | PHS · staging server | € 0 | € 0 |
| **Subtotaal Identiteit** | | **€ 2.700** | **€ 32.400** |

### Security

| Resource | SKU / Configuratie | Prijs/mnd | Prijs/jaar |
|---|---|---:|---:|
| Key Vault Standard — Workload | Secrets · certs · soft-delete · PE | € 1 | € 12 |
| Key Vault Standard — Platform | TLS-certs · platform secrets | € 4 | € 48 |
| Managed Identity | System-assigned · App + Functions | € 0 | € 0 |
| Microsoft Defender for Cloud | Servers P2 · SQL MI · Storage · App Svc | € 125 | € 1500 |
| PIM — Just-in-Time Access | Inbegrepen in Entra ID P1 | € 0 | € 0 |
| Conditional Access | Inbegrepen in Entra ID P1 | € 0 | € 0 |
| **Subtotaal Security** | | **€ 130** | **€ 1560** |

### Monitoring

| Resource | SKU / Configuratie | Prijs/mnd | Prijs/jaar |
|---|---|---:|---:|
| Log Analytics Workspace | 8 GB/dag · 90d hot · 2j archief | € 552 | € 6.624 |
| Application Insights | APM · traces · 5 GB/mnd | € 12 | € 144 |
| Azure Monitor | Metrics · dashboards · alerts | € 10 | € 120 |
| Automation Account | 500 job-min/mnd (gratis tier) | € 1 | € 12 |
| **Subtotaal Monitoring** | | **€ 575** | **€ 6.900** |

### Integratie

| Resource | SKU / Configuratie | Prijs/mnd | Prijs/jaar |
|---|---|---:|---:|
| Service Bus Standard | Standard · ~10M berichten/mnd | € 8 | € 96 |
| Azure Communication Services | E-mail delivery · ~1.000 mails/mnd | € 1 | € 12 |
| **Subtotaal Integratie** | | **€ 9** | **€ 108** |

---

## 3. Maandelijks kostenoverzicht

### Productie (Contoso-Prod subscriptie)

| Categorie | Prijs/mnd (PAYG) | % van totaal |
|---|---:|---:|
| Netwerk | € 1.734 | 17,6% |
| Compute | € 1.376 | 14,0% |
| Database | € 2.912 | 29,6% |
| Storage | € 118 | 1,2% |
| Identiteit | € 2.700 | 27,4% |
| Security | € 130 | 0,6% |
| Monitoring | € 575 | 5,8% |
| Integratie | € 9 | 0,1% |
| **Subtotaal Prod** | **€ 9.614** | |

### NonProd (Contoso-NonProd subscriptie — Dev/Test pricing)

| Resource | SKU Dev/Test | Prijs/mnd |
|---|---|---:|
| App Service B1 (web + api) | B1 · Dev/Test pricing · 1 inst. | € 12 |
| SQL Database Serverless | GP Serverless · auto-pause 1u | € 45 |
| Azure Functions Consumption | Consumption | € 2 |
| Storage Account LRS | LRS · Cool · 200 GB | € 4 |
| **Subtotaal NonProd** | | **€ 63** |

### Totaaloverzicht

| Scenario | Prijs/mnd | Prijs/jaar |
|---|---:|---:|
| PAYG totaal (Prod + NonProd) | **€ 9.850** | **€ 118.200** |
| Na Azure Hybrid Benefit (AHB) | **€ 8.407** | **€ 100.884** |
| Na AHB + Reserved Instances 1J | **€ 6.107** | **€ 73.284** |

> De database (SQL MI × 2) en identiteit (Entra ID P1) zijn samen goed voor **57%** van de totale maandkost.

---

> Aannames: PAYG €9.850/mnd · RI+AHB €6.107/mnd · On-prem capex €320.000 eenmalig + €96.000 opex/jaar · Migratie €35.000 eenmalig · RI-investering €18.000 jaar 1

```
                       Jaar 1        Jaar 2        Jaar 3      TOTAAL 3J
────────────────────────────────────────────────────────────────────────────
ON-PREMISES
  Capex (hardware, licenties, F5, netwerk)
                      €320.000           €0            €0      €320.000
  Opex/jaar (onderhoud, hosting, IT-beheer)
                       €96.000       €96.000       €96.000      €288.000
  Subtotaal           €416.000       €96.000       €96.000      €608.000

────────────────────────────────────────────────────────────────────────────
AZURE (Pay-as-you-go)
  Maandkost × 12      €118.200      €118.200      €118.200      €354.600
  Migratie (eenmalig)  €35.000           €0            €0       €35.000
  Subtotaal           €153.200      €118.200      €118.200      €389.600

────────────────────────────────────────────────────────────────────────────
AZURE (Reserved Instances 1J + AHB)
  Maandkost × 12       €73.284       €73.284       €73.284      €219.852
  RI-investering jaar 1 €18.000          €0            €0       €18.000
  Migratie (eenmalig)  €35.000           €0            €0       €35.000
  Subtotaal           €126.284       €73.284       €73.284      €272.852

────────────────────────────────────────────────────────────────────────────
BESPARING
  Azure PAYG    vs On-prem              €262.800      €479.800   €218.400 (35,9%)
  Azure RI+AHB  vs On-prem              €289.800      €522.800   €335.148 (55,1%)
  Azure RI+AHB  vs Azure PAYG                                    €116.748 (19,2%)
────────────────────────────────────────────────────────────────────────────
```

**Break-even:** Azure RI+AHB wordt goedkoper dan on-prem renovatie na **maand 9–11 van jaar 1**, doordat de eenmalige capex van €320.000 volledig in jaar 1 valt.

### On-premises kostendetail

| Kostenpost | Eenmalig (jaar 1) | Jaarlijks (jaar 2–3) | Onderbouwing |
|---|---:|---:|---|
| Hardware vervanging (9 servers) | € 180.000 | — | €20K/server gemiddeld |
| Windows Server 2022 licenties | € 25.000 | — | 9× dual-socket |
| SQL Server 2022 Enterprise | € 60.000 | — | 2× dual-socket |
| F5 BIG-IP vervanging | € 35.000 | € 5.000 | EOL 2025 — verplicht |
| Netwerkapparatuur refresh | € 20.000 | € 3.000 | Switches, routers |
| Datacenter hosting / co-locatie | — | € 30.000 | Jaarlijks herhalend |
| IT-beheer (0,5 FTE × €80K) | — | € 40.000 | Systeembeheerder |
| Onderhoud hardware (10%/jaar) | — | € 18.000 | 10% van hardware capex |
| **Totaal** | **€ 320.000** | **€ 96.000** | |

---

## 5. Optimalisatieadvies

### 5.1 Azure Hybrid Benefit (AHB) — directe besparing

Contoso heeft Windows Server Datacenter SA en SQL Server Enterprise SA — beide actief. AHB moet **manueel worden ingeschakeld** bij deployment.

| Licentie | Resource | Korting | Jaarlijkse besparing |
|---|---|:---:|---:|
| Windows Server Datacenter SA | App Service P2v3 × 2 (web + api) | 18% | € 2.666,52 |
| Windows Server Datacenter SA | vm-dc-01 (B2ms) | 40% | € 336,38 |
| Windows Server Datacenter SA | vm-dc-02 (B2ms) | 40% | € 336,38 |
| SQL Server Enterprise SA | SQL MI GP 8vCore — Prod | 40% | € 6.988,80 |
| SQL Server Enterprise SA | SQL MI GP 8vCore — DR | 40% | € 6.988,80 |
| **TOTAAL AHB** | | | **€ 17.316,88 / jaar** |

**AHB activeren in Bicep:**
```bicep
resource appService 'Microsoft.Web/sites@2022-09-01' = {
  properties: {
    siteConfig: {
      windowsFxVersion: 'DOTNET|4.8'
    }
  }
}
// Voor VMs:
resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  properties: {
    licenseType: 'Windows_Server'
  }
}
```

### 5.2 Reserved Instances (RI) — commitment-korting

Door 1 jaar vooruit te betalen voor de grootste resources vermijdt Contoso PAYG-meerkosten van ~€2.900/jaar.

| Resource | PAYG/mnd | RI korting | Na RI/mnd | Jaarlijkse besparing |
|---|---:|:---:|---:|---:|
| App Service P2v3 × 2 | € 1.234 | 30% | € 864 | € 4.441 |
| SQL MI GP 8vCore — Prod | € 1.456 | 33% | € 976 | € 5.760 |
| SQL MI GP 8vCore — DR | € 1.456 | 33% | € 976 | € 5.760 |
| VPN Gateway VpnGw2 | € 268 | 36% | € 172 | € 1.152 |
| DC VMs (2× B2ms) | € 140 | 40% | € 84 | € 672 |
| **TOTAAL RI besparing** | | | | **€ 17.785 / jaar** |

> RI's kunnen worden aangeschaft via de Azure Portal of via Bicep. Ze zijn uitwisselbaar binnen dezelfde VM-familie.

### 5.3 Auto-scale — flexibele compute

App Service schaalt automatisch van 2 naar 6 instanties op basis van CPU-gebruik:

```json
{
  "scaleOut": { "trigger": "CPU > 70% gedurende 5 min", "action": "+1 instantie" },
  "scaleIn":  { "trigger": "CPU < 30% gedurende 10 min", "action": "-1 instantie" },
  "minimum": 2,
  "maximum": 6
}
```

**Kostenbesparing auto-scale:** buiten kantooruren (16u/24u) draaien slechts 2 instanties. Bij 4 gemiddeld piek-uur/dag besparing van ~€308/mnd t.o.v. altijd 4 instanties draaien.

### 5.4 Dev/Test pricing — NonProd

Via een Dev/Test-subscriptie betaalt Contoso tot 55% minder voor NonProd-resources:

| Resource | Prod (PAYG) | NonProd (Dev/Test) | Besparing |
|---|---:|---:|---:|
| App Service (web + api) | € 1.234/mnd | € 12/mnd | € 1.222/mnd |
| SQL MI → SQL DB Serverless | € 1.456/mnd | € 45/mnd | € 1.411/mnd |
| **Totale NonProd besparing** | | | **€ 2.633/mnd** |

### 5.5 Lifecycle policies Storage

Stel een lifecycle policy in op de Storage Account om rapporten ouder dan 30 dagen automatisch naar Cool tier te verplaatsen:

```bicep
resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = {
  properties: {
    policy: {
      rules: [{
        name: 'move-to-cool'
        type: 'Lifecycle'
        definition: {
          filters: { blobTypes: ['blockBlob'], prefixMatch: ['rapporten/'] }
          actions: { baseBlob: { tierToCool: { daysAfterModificationGreaterThan: 30 } } }
        }
      }]
    }
  }
}
```

**Besparing:** ~€0,010/GB/mnd op rapporten ouder dan 30 dagen → geschat €20/mnd bij 2 TB.

---

## 6. Risico's

Onderstaande onzekerheden kunnen de werkelijke kosten doen afwijken van de inschatting. Per risico wordt de richting en de impact vermeld.

| # | Risico | Richting | Kans | Impact | Mitigatie |
|---|---|:---:|:---:|:---:|---|
| R1 | **Egress-verkeer hoger dan 500 GB/mnd** — meer externe rapportage of API-integraties dan voorzien | ↑ kosten | Middel | Laag (+€43/mnd per 500 GB) | Maandelijks monitoren via Azure Cost Analysis. Overweeg Azure CDN voor statische assets. |
| R2 | **Log Analytics ingestie hoger dan 8 GB/dag** — meer resources, verbose logging of security-events | ↑ kosten | Middel | Middel (+€69/mnd per GB/dag) | Diagnostics-instellingen per resource fijnstellen. Sampling instellen in Application Insights. |
| R3 | **Database groei sneller dan 15%/jaar** — meer data door groei productievolumes of nieuwe modules | ↑ kosten | Laag | Laag (extra storage < €0,12/GB/mnd) | Jaarlijkse capaciteitsplanning. SQL MI schaalt storage onafhankelijk van compute. |
| R4 | **AHB SA-licenties verlopen** — Windows of SQL Server SA niet tijdig verlengd | ↑ kosten | Laag | Hoog (€17.317/jaar extra) | SA-vervaldatum opvolgen via [VLSC](https://www.microsoft.com/licensing/servicecenter). Reminder 6 maanden voor vervaldatum. |
| R5 | **Entra ID P1-prijs wijziging** — Microsoft past licentieprijs aan (historisch ~5-10% per 2 jaar) | ↑ kosten | Middel | Middel (€270/mnd per 10% stijging) | Enterprise Agreement overwegen bij > 500 gebruikers. |
| R6 | **DDoS Protection Standard** — indien alsnog vereist door beleid of Front Door toevoeging | ↑ kosten | Laag | Hoog (+€2.944/mnd) | Huidig scenario: DDoS Basic (gratis) + WAF op AGW. Alleen activeren als Front Door of externe exposure vereist. |
| R7 | **SQL MI Business Critical upgrade** — als CPU continu > 80% of in-memory OLTP nodig wordt | ↑ kosten | Laag | Hoog (+€1.800/mnd) | CPU-monitoring na go-live. Upgrade pas na 3 maanden productie-data. |
| R8 | **Migratiekost onderschatting** — complexere data-migratie of langere run-parallel periode | ↑ kosten | Middel | Middel (+€15K–50K eenmalig) | Gedetailleerde migratieplanning vóór go-live. Buffer van €20K opnemen in projectbudget. |
| R9 | **Egress naar on-prem via VPN** — hoog datavolume vanuit Azure naar Gent/Luik/Hasselt | ↑ kosten | Laag | Laag | VNet Peering en VPN-verkeer is intern Azure — egress-tarieven gelden enkel voor extern internet. |
| R10 | **Reserved Instances niet tijdig besteld** — go-live zonder RI → PAYG-meerkosten jaar 1 | ↑ kosten | Middel | Middel (+€2.900/jaar) | RI's bestellen minimum 1 maand vóór go-live. Kan ook achteraf worden omgezet. |

### Gevoeligheidsanalyse — scenario's

| Scenario | Maandkost | Afwijking vs basisscenario |
|---|---:|---:|
| Basisscenario (RI + AHB) | € 6.107 | — |
| AHB verloopt (geen SA-verlenging) | € 7.550 | +€ 1.443/mnd |
| Log Analytics 12 GB/dag i.p.v. 8 GB | € 6.383 | +€ 276/mnd |
| Egress 1 TB/mnd i.p.v. 500 GB | € 6.150 | +€ 43/mnd |
| DDoS Standard toegevoegd | € 9.051 | +€ 2.944/mnd |
| SQL MI upgrade naar Business Critical | € 7.907 | +€ 1.800/mnd |
| **Worst case (alle risico's tegelijk)** | **~€ 14.000** | **+€ 7.893/mnd** |

---

## Bronnen

- [Azure Pricing Calculator (2025)](https://azure.microsoft.com/pricing/calculator/)
- [Azure TCO Calculator](https://azure.microsoft.com/pricing/tco/calculator/)
- [Azure Hybrid Benefit](https://azure.microsoft.com/pricing/hybrid-benefit/)
- [Microsoft Volume Licensing Service Center (VLSC)](https://www.microsoft.com/licensing/servicecenter)
- [Azure SQL MI Resource Limits](https://docs.microsoft.com/azure/azure-sql/managed-instance/resource-limits)
- [Azure Landing Zone v2](https://learn.microsoft.com/azure/cloud-adoption-framework/ready/landing-zone/)
- [NIS2-richtlijn (2022/2555)](https://eur-lex.europa.eu/legal-content/NL/TXT/?uri=CELEX%3A32022L2555)

---

*Versie 1.0 · team-cloud@contoso.be · West Europe 2025 · INTERN — vertrouwelijk*

---
