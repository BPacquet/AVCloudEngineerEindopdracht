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

## richtlijnen & aannames

### regio
Gebruik **West Europe (Amsterdam)** als primaire regio en **North Europe (Dublin)** als secondary/DR-regio voor geo-redundante resources.

> 💡 Tip: West Europe is doorgaans 5–10% duurder dan North Europe. Overweeg welke resources echt in West Europe moeten staan.

### aannames te documenteren

Documenteer in je README **elke aanname** die je maakt, zoals:
- Aantal gebruikers (concurrent en totaal)
- Datatransfer volumes (in/uit)
- Backup retentie periode
- Verwachte database groei per jaar
- Peak vs. average CPU-gebruik

### Azure Hybrid Benefit (AHB)

De klant beschikt over:
- Windows Server Datacenter licenties (Software Assurance)
- SQL Server Enterprise licenties (Software Assurance)

Bereken de besparing die AHB oplevert op de Azure-resources.

---

## te schatten resources (minimaal)

Onderstaande tabel is een **startpunt** — je architectuurkeuzes kunnen afwijken. Onderbouw elke keuze.

### Compute

| Resource | SKU voorstel | Regio | Opmerkingen |
|---|---|---|---|
| App Service Plan (Web) | P2v3 of P3v3 | West Europe | Minimaal 2 instances voor HA |
| App Service Plan (API/Worker) | P1v3 | West Europe | Windows services refactored als WebJobs of Functions |
| Azure Functions (optioneel) | Consumption of Premium | West Europe | Voor batch jobs |

### Database

| Resource | SKU voorstel | Regio | Opmerkingen |
|---|---|---|---|
| Azure SQL Database | Business Critical of General Purpose | West Europe | 500 GB, onderbouw tier keuze |
| SQL Geo-replication | — | North Europe | Secondary read replica voor DR |

### Netwerk

| Resource | Regio | Opmerkingen |
|---|---|---|
| Azure Firewall | West Europe | Premium tier voor IDPS |
| Application Gateway + WAF | West Europe | WAF_v2 |
| VPN Gateway of ExpressRoute | West Europe | Keuze onderbouwen |
| Private DNS Zones | Global | Per PaaS-dienst |
| Bandwidth (egress) | — | Schat maandelijks dataverkeer |

### Security & Identity

| Resource | Opmerkingen |
|---|---|
| Microsoft Entra ID (P1 of P2) | Per gebruiker, onderbouw tier |
| Key Vault | Standard of Premium (HSM) |
| Defender for Cloud | Welke plans? Onderbouw per resource type |

### Monitoring

| Resource | Opmerkingen |
|---|---|
| Log Analytics Workspace | Schat GB/dag aan logs |
| Application Insights | Per applicatie |
| Azure Monitor (alerts, dashboards) | Inbegrepen / additief |

### Storage

| Resource | SKU | Opmerkingen |
|---|---|---|
| Storage Account (blobs, bestanden) | LRS of GRS, Hot tier | Rapporten, uploads |
| Azure Backup | — | Koppel aan RPO/RTO vereisten |

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

---

## te gebruiken tools

| Tool | Link | Gebruik |
|---|---|---|
| Azure Pricing Calculator | https://azure.microsoft.com/pricing/calculator/ | Maandelijkse Azure-kost |
| Azure TCO Calculator | https://azure.microsoft.com/pricing/tco/calculator/ | On-prem vs Azure vergelijking |
| Azure Hybrid Benefit (rekentool) | https://azure.microsoft.com/pricing/hybrid-benefit/ | AHB besparing |

---

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

---