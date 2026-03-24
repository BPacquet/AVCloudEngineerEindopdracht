# 03 — netwerkdiagram & documentatie

> **Deliverable**: Hub-Spoke netwerkontwerp, subnetting, NSG's, DNS  
> **Gewicht**: 15% van de totale eindopdrachtscore

---

## opdracht

Ontwerp het volledige Azure-netwerk voor de Contoso-migratie. Je documenterrt het netwerk in een diagram en een bijhorende technische documentatie.

---

## vereiste componenten

### topologie: hub-spoke

Gebruik de **Hub-Spoke netwerktopologie** als basis. Dit is de Microsoft-aanbevolen topologie voor Enterprise-omgevingen en sluit aan bij de Landing Zone architectuur.

```
                         ┌─────────────────────────────────┐
                         │   CONNECTIVITY SUBSCRIPTION     │
                         │                                 │
   ON-PREMISES           │   ┌─────────────────────────┐   │
   10.10.0.0/16  ◄───────┼───┤   HUB VNet              │   │
   (Gent/Luik/           │   │   10.0.0.0/16           │   │
    Hasselt)             │   │                         │   │
        │                │   │  ┌─────────────────┐   │   │
        │ VPN/ExpressRoute│   │  │ AzureFirewallSub│   │   │
        │                │   │  │ 10.0.0.0/26     │   │   │
        │                │   │  └─────────────────┘   │   │
        │                │   │  ┌─────────────────┐   │   │
        │                │   │  │ GatewaySubnet   │   │   │
        │                │   │  │ 10.0.1.0/27     │   │   │
        │                │   │  └─────────────────┘   │   │
        │                │   │  ┌─────────────────┐   │   │
        │                │   │  │ AzureBastionSub │   │   │
        │                │   │  │ 10.0.2.0/27     │   │   │
        │                │   │  └─────────────────┘   │   │
        │                │   └─────────────────────────┘   │
        └────────────────┼───────────────┐                 │
                         │               │ VNet Peering     │
                         │               ▼                 │
                         └─────────────────────────────────┘
                                         │
                         ┌───────────────▼─────────────────┐
                         │   WORKLOAD SUBSCRIPTION         │
                         │                                 │
                         │   ┌─────────────────────────┐   │
                         │   │   SPOKE VNet            │   │
                         │   │   10.20.0.0/16          │   │
                         │   │                         │   │
                         │   │  [subnetten — zie onder]│   │
                         │   └─────────────────────────┘   │
                         └─────────────────────────────────┘
```

---

## subnettingschema

### Hub VNet — `10.0.0.0/16` (Connectivity Subscription)

| Subnet naam | CIDR | Doel | NSG? |
|---|---|---|---|
| `AzureFirewallSubnet` | `10.0.0.0/26` | Azure Firewall (vereiste naam!) | ❌ (niet ondersteund) |
| `AzureFirewallManagementSubnet` | `10.0.0.64/26` | Firewall management | ❌ |
| `GatewaySubnet` | `10.0.1.0/27` | VPN/ExpressRoute Gateway | ❌ (vereiste naam!) |
| `AzureBastionSubnet` | `10.0.2.0/27` | Azure Bastion | ❌ (vereiste naam!) |
| `snet-hub-dns` | `10.0.3.0/28` | Azure DNS Private Resolver | ✅ |

> ⚠️ **Let op**: `AzureFirewallSubnet`, `GatewaySubnet` en `AzureBastionSubnet` zijn **vereiste exacte namen** — Azure accepteert geen andere namen voor deze speciale subnetten.

### Spoke VNet — `10.20.0.0/16` (Workload Subscription)

Ontwerp minimaal de volgende subnetten. Kies zelf de CIDR-ranges (documenteer je redenering):

| Subnet naam | CIDR (te bepalen) | Doel | NSG vereist? |
|---|---|---|---|
| `snet-spoke-appgw` | `10.20.X.X/??` | Application Gateway + WAF | ✅ |
| `snet-spoke-web` | `10.20.X.X/??` | App Service VNet Integration | ✅ |
| `snet-spoke-func` | `10.20.X.X/??` | Functions VNet Integration | ✅ |
| `snet-spoke-data` | `10.20.X.X/??` | Private Endpoints (SQL, Storage, KV) | ✅ |
| `snet-spoke-mgmt` | `10.20.X.X/??` | Management/Jump VMs (indien van toepassing) | ✅ |

**Vul in**: Kies je CIDR-ranges en onderbouw de grootte (hoeveel IP-adressen heb je nodig?).

> 💡 Tip: Azure reserveert 5 IP-adressen per subnet (0, 1, 2, 3, 255). Plan daar rekening mee.

---

## NSG-regels

Documenteer de **minimaal vereiste NSG-regels** per subnet. Gebruik onderstaande format:

### NSG: `nsg-appgw` (Application Gateway subnet)

| Prioriteit | Naam | Richting | Protocol | Bron | Doel | Poort | Actie |
|---|---|---|---|---|---|---|---|
| 100 | Allow-GatewayManager | Inbound | TCP | GatewayManager | `*` | 65200–65535 | Allow |
| 110 | Allow-AzureLoadBalancer | Inbound | TCP | AzureLoadBalancer | `*` | `*` | Allow |
| 120 | Allow-HTTPS-Inbound | Inbound | TCP | Internet | `*` | 443 | Allow |
| 130 | Allow-HTTP-Inbound | Inbound | TCP | Internet | `*` | 80 | Allow |
| 4096 | Deny-All-Inbound | Inbound | `*` | `*` | `*` | `*` | Deny |

> ⚠️ **Let op**: Application Gateway vereist de GatewayManager-regel — anders werkt de health probing niet!

### NSG: `nsg-web` (App Service VNet Integration subnet)

| Prioriteit | Naam | Richting | Protocol | Bron | Doel | Poort | Actie |
|---|---|---|---|---|---|---|---|
| 100 | Allow-AppGW-to-Web | Inbound | TCP | snet-spoke-appgw | `*` | 443 | Allow |
| 200 | Allow-Web-to-Data | Outbound | TCP | `*` | snet-spoke-data | 1433 | Allow |
| 300 | Allow-Web-to-KV | Outbound | TCP | `*` | snet-spoke-data | 443 | Allow |
| ... | ... | ... | ... | ... | ... | ... | ... |
| 4096 | Deny-All | Inbound | `*` | `*` | `*` | `*` | Deny |

**Vul aan**: Maak vergelijkbare NSG-tabellen voor `nsg-func` en `nsg-data`.

---

## private endpoints

Documenteer alle **Private Endpoints** in de architectuur:

| Resource | Private Endpoint naam | Subnet | DNS Zone |
|---|---|---|---|
| Azure SQL Database | `pep-sql-contoso-prd` | `snet-spoke-data` | `privatelink.database.windows.net` |
| Storage Account | `pep-st-contoso-prd` | `snet-spoke-data` | `privatelink.blob.core.windows.net` |
| Key Vault | `pep-kv-contoso-prd` | `snet-spoke-data` | `privatelink.vaultcore.azure.net` |
| App Service (optioneel) | `pep-app-contoso-prd` | `snet-spoke-web` | `privatelink.azurewebsites.net` |

### waarom private endpoints?

Documenteer in 3–5 zinnen waarom je Private Endpoints gebruikt in plaats van Service Endpoints. Wat zijn de voordelen en nadelen?

---

## DNS-architectuur

### vereiste DNS Private Zones

| Private DNS Zone | Gekoppeld aan | Doel |
|---|---|---|
| `privatelink.database.windows.net` | Hub VNet | SQL Database |
| `privatelink.blob.core.windows.net` | Hub VNet | Storage (blob) |
| `privatelink.file.core.windows.net` | Hub VNet | Storage (files) |
| `privatelink.vaultcore.azure.net` | Hub VNet | Key Vault |
| `privatelink.azurewebsites.net` | Hub VNet | App Service (indien PE) |

### DNS-resolutie flow

Beschrijf de DNS-resolutie flow voor een request vanuit on-prem naar de Azure SQL Private Endpoint:

```
On-prem client
  │
  ▼
On-prem DNS Server (DC01)
  │  "sql-contoso-prd.database.windows.net" — conditionally forwarded naar Azure
  ▼
Azure DNS Private Resolver (snet-hub-dns)
  │  Zoekt in Private DNS Zone: privatelink.database.windows.net
  ▼
Private Endpoint IP: 10.20.X.X (snet-spoke-data)
  │
  ▼
Azure SQL Database (via private network, geen publiek internet)
```

**Vul in**: Teken dit diagram netter en documenteer welke DNS-forwarder-configuratie nodig is op DC01.

---

## azure firewall regels

Documenteer de **minimaal vereiste Azure Firewall regels**:

### Application Rules (FQDN-gebaseerd)

| Naam | Bron | Protocol | Target FQDN | Actie |
|---|---|---|---|---|
| Allow-WindowsUpdate | `10.20.0.0/16` | HTTPS | `*.update.microsoft.com` | Allow |
| Allow-AzureMonitor | `10.20.0.0/16` | HTTPS | `*.monitor.azure.com` | Allow |
| Allow-SAP-API | `10.20.0.0/16` | HTTPS | `sap-api.contoso.local` | Allow |

### Network Rules (IP-gebaseerd)

| Naam | Bron | Protocol | Doel | Poort | Actie |
|---|---|---|---|---|---|
| Allow-Onprem-to-Azure | `10.10.0.0/16` | TCP | `10.20.0.0/16` | 443,1433 | Allow |
| Allow-Azure-to-Onprem-SMTP | `10.20.0.0/16` | TCP | `10.10.X.X` (Exchange) | 25 | Allow |

**Vul aan**: Voeg alle vereiste regels toe voor de Contoso applicatie.

---

## wat je inlevert

```
03-network/
├── README.md              ← dit bestand, volledig ingevuld
└── network-diagram.png    ← volledig netwerkdiagram
```

### inhoud README (volledig ingevuld)

1. Topologiebeschrijving
2. Subnettingschema (Hub + Spoke)
3. NSG-regels per subnet
4. Private Endpoints tabel
5. DNS-architectuur en resolutie flow
6. Azure Firewall regels
7. Verbinding on-prem (VPN of ExpressRoute, met onderbouwing)

---

## beoordelingscriteria (15 punten)

| Criterium | Punten |
|---|---|
| Hub-Spoke diagram correct en volledig | 4 |
| Subnetting correct met CIDR-onderbouwing | 3 |
| NSG-regels correct (min. 3 subnetten) | 3 |
| Private Endpoints gedocumenteerd | 2 |
| DNS-architectuur correct beschreven | 2 |
| Azure Firewall regels aanwezig | 1 |

---

_Ga verder naar [`../04-security/README.md`](../04-security/README.md)_

---

_delaware cloud practice — we commit. we deliver._
