# 03 — netwerkdiagram & documentatie

> **Deliverable**: Hub-Spoke netwerkontwerp, subnetting, NSG's, DNS  
> **Gewicht**: 15% van de totale eindopdrachtscore

---

## opdracht

Ontwerp het volledige Azure-netwerk voor de Contoso-migratie. Je documenterrt het netwerk in een diagram en een bijhorende technische documentatie.

---

## vereiste componenten

### topologie: hub-spoke

<img width="1472" height="1360" alt="image" src="https://github.com/user-attachments/assets/dd1413bc-8428-449b-8022-a857c7bef41e" />

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
| `snet-hub-mgmt` | `10.0.4.0/28` | Management (gereserveerd) | ✅ |

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
.0 (network), .1 (default gateway), .2 en .3 (Azure DNS), .255 (broadcast).
> 
| Subnet           | CIDR         | Totaal | Bruikbaar | Dimensionering                                                                                                                             |
| ---------------- | ------------ | ------ | --------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| snet-spoke-appgw | 10.20.0.0/27 | 32     | 27        | AGW WAF v2 vereist 1 IP per instantie + VIP. Max 10 instanties bij Contoso = 11 IPs. /27 geeft 27 bruikbare adressen — ruim voldoende.                        |
| snet-spoke-web   | 10.20.1.0/24 | 256    | 251       | App Service VNet Integration delegeert het hele subnet aan het platform. Microsoft vereist min. /27 per App Service Plan. Met 2 plans (web + api) en auto-scale tot 6 instanties elk = 12 IPs actief. /24 geeft groeimarge voor extra plans |
| snet-spoke-func  | 10.20.2.0/27 | 32     | 27        | Function Apps met lage gelijktijdigheid. Microsoft vereist minimaal /27, dus dit is voldoende voor huidige workloads.                      |
| snet-spoke-data  | 10.20.3.0/24 | 256    | 251       | Alleen Private Endpoints (elk 1 IP). Huidig ~5 PE’s, /24 geeft voldoende ruimte voor uitbreiding zonder toekomstige herindeling.                       |
| snet-spoke-mgmt  | 10.20.4.0/27 | 32     | 27        | Management VMs en DevOps agents (±5–10 verwacht). /27 biedt voldoende capaciteit met marge.                                                |


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

## nsg-func

**Subnet:** `snet-spoke-func` | **CIDR:** `10.20.2.0/27` | **Resource:** Azure Functions Consumption + VNet Integration (`fn-contoso-prd-001`)

> ℹ️ Functions Consumption met VNet Integration stuurt **uitgaand** verkeer via dit subnet. Inbound trigger-aanroepen verlopen via het Azure Functions host-platform — geen directe inbound NSG-regel nodig voor triggers. Delegatie: `Microsoft.Web/serverFarms`. `/27` is het Microsoft-minimum voor VNet Integration.

### Inbound

| Prioriteit | Naam | Protocol | Bron | Doel | Poort | Actie | Toelichting |
|:---:|---|:---:|---|:---:|:---:|:---:|---|
| 100 | `Allow-AzureFunc-Management` | TCP | `AzureFunctions` | `*` | 443 | ✅ Allow | Azure Functions platform management en health checks — service tag |
| 110 | `Allow-AzureCloud` | TCP | `AzureCloud` | `*` | 443 | ✅ Allow | Functions host-communicatie met Azure Cloud voor triggers en bindings |
| 120 | `Allow-Bastion-Mgmt` | TCP | `AzureBastionSubnet` | `*` | 22, 3389 | ✅ Allow | Beheer via Bastion bij gebruik van Premium-plan met dedicated instances |
| 4096 | `Deny-All-Inbound` | `*` | `*` | `*` | `*` | 🚫 Deny | Default deny — Functions ontvangt triggers via intern Azure-platform |

### Outbound

| Prioriteit | Naam | Protocol | Bron | Doel | Poort | Actie | Toelichting |
|:---:|---|:---:|---|:---:|:---:|:---:|---|
| 100 | `Allow-Func-to-SQL` | TCP | `*` | `snet-spoke-data` | 1433 | ✅ Allow | Reporter-functie via PE `10.20.3.4` naar SQL MI voor rapportage |
| 110 | `Allow-Func-to-ServiceBus` | TCP | `*` | `snet-spoke-data` | 5671, 5672 | ✅ Allow | Processor-functie leest berichten van Service Bus via PE `10.20.3.7` — AMQP |
| 120 | `Allow-Func-to-Storage` | TCP | `*` | `snet-spoke-data` | 443 | ✅ Allow | Functions vereist Storage Account voor state, triggers en deployment |
| 130 | `Allow-Func-to-KV` | TCP | `*` | `snet-spoke-data` | 443 | ✅ Allow | Key Vault via Managed Identity en PE `10.20.3.6` voor secrets |
| 140 | `Allow-Func-to-AzureMonitor` | TCP | `*` | `AzureMonitor` | 443 | ✅ Allow | Application Insights traces en telemetrie naar Azure Monitor |
| 150 | `Allow-Func-to-AzureAD` | TCP | `*` | `AzureActiveDirectory` | 443 | ✅ Allow | Managed Identity token-aanvragen naar Entra ID — service tag |
| 160 | `Allow-Func-to-DNS` | UDP | `*` | `snet-hub-dns` | 53 | ✅ Allow | DNS-resolutie via Hub DNS Private Resolver voor `privatelink.*` namen |
| 4096 | `Deny-All-Outbound` | `*` | `*` | `*` | `*` | 🚫 Deny | Default deny — al het overige outbound geblokkeerd |

---

## nsg-data

**Subnet:** `snet-spoke-data` | **CIDR:** `10.20.3.0/24` | **Resource:** Private Endpoints — SQL MI · Blob ZRS · Key Vault · Service Bus · App Service

> ⚠️ Dit subnet bevat **uitsluitend Private Endpoints**. Geen compute, geen App Service resources. NSG-regels beperken inbound tot de subnetten die PEs mogen aanroepen. Elke PE gebruikt 1 IP-adres.
>
> | Private Endpoint | IP-adres |
> |---|---|
> | SQL Managed Instance | `10.20.3.4` |
> | Blob Storage (ZRS) | `10.20.3.5` |
> | Key Vault | `10.20.3.6` |
> | Service Bus | `10.20.3.7` |
> | App Service | `10.20.3.8` |

### Inbound

| Prioriteit | Naam | Protocol | Bron | Doel | Poort | Actie | Toelichting |
|:---:|---|:---:|---|:---:|:---:|:---:|---|
| 100 | `Allow-Web-to-SQL-PE` | TCP | `snet-spoke-web` | `*` | 1433 | ✅ Allow | App Service (web + api) via PE `10.20.3.4` naar SQL MI |
| 110 | `Allow-Func-to-SQL-PE` | TCP | `snet-spoke-func` | `*` | 1433 | ✅ Allow | Azure Functions (Reporter) via PE `10.20.3.4` naar SQL MI |
| 120 | `Allow-Web-to-KV-PE` | TCP | `snet-spoke-web` | `*` | 443 | ✅ Allow | App Service haalt secrets op via PE `10.20.3.6` naar Key Vault |
| 130 | `Allow-Func-to-KV-PE` | TCP | `snet-spoke-func` | `*` | 443 | ✅ Allow | Azure Functions haalt secrets op via PE `10.20.3.6` naar Key Vault |
| 140 | `Allow-Web-to-Blob-PE` | TCP | `snet-spoke-web` | `*` | 443 | ✅ Allow | App Service leest/schrijft rapporten via PE `10.20.3.5` naar Blob Storage |
| 150 | `Allow-Func-to-SB-PE` | TCP | `snet-spoke-func` | `*` | 5671, 5672 | ✅ Allow | Functions leest berichten via PE `10.20.3.7` van Service Bus — AMQP |
| 160 | `Allow-Web-to-SB-PE` | TCP | `snet-spoke-web` | `*` | 5671, 5672 | ✅ Allow | App Service publiceert berichten via PE `10.20.3.7` naar Service Bus |
| 170 | `Allow-Mgmt-to-Data` | TCP | `snet-spoke-mgmt` | `*` | 443, 1433 | ✅ Allow | DevOps agents en jump VMs voor database-beheer en Key Vault-operaties |
| 4096 | `Deny-All-Inbound` | `*` | `*` | `*` | `*` | 🚫 Deny | Default deny — PE-subnet niet bereikbaar vanuit internet of andere subnetten |

### Outbound

| Prioriteit | Naam | Protocol | Bron | Doel | Poort | Actie | Toelichting |
|:---:|---|:---:|---|:---:|:---:|:---:|---|
| 100 | `Allow-PE-to-SQL-MI` | TCP | `*` | `snet-sqli-dedicated` | 1433 | ✅ Allow | PE SQL MI stuurt verkeer door naar SQL MI in dedicated subnet |
| 110 | `Allow-PE-to-Azure-Storage` | TCP | `*` | `Storage` | 443 | ✅ Allow | PE Blob/Files stuurt door naar Azure Storage — service tag |
| 120 | `Allow-PE-to-Azure-KV` | TCP | `*` | `AzureKeyVault` | 443 | ✅ Allow | PE Key Vault stuurt door naar KV service — service tag |
| 130 | `Allow-PE-to-Azure-SB` | TCP | `*` | `ServiceBus` | 5671, 5672 | ✅ Allow | PE Service Bus stuurt door naar SB service — service tag |
| 140 | `Allow-DNS` | UDP | `*` | `snet-hub-dns` | 53 | ✅ Allow | DNS-resolutie voor PE-hostnamen via Hub DNS Private Resolver |
| 4096 | `Deny-All-Outbound` | `*` | `*` | `*` | `*` | 🚫 Deny | Default deny — PE-subnet communiceert enkel met PaaS-services |

---

## nsg-sqli

**Subnet:** `snet-sqli-dedicated` | **CIDR:** `10.20.4.0/24` | **Resource:** SQL Managed Instance GP — DEDICATED subnet

> ⚠️ SQL MI vereist speciale NSG-regels gedocumenteerd door Microsoft. **Ontbrekende regels veroorzaken deployment-fouten.** Dit subnet is DEDICATED — geen andere resources zijn toegestaan. Microsoft reserveert intern 16+ IP-adressen voor het 3-node HA-cluster.

### Inbound

| Prioriteit | Naam | Protocol | Bron | Doel | Poort | Actie | Toelichting |
|:---:|---|:---:|---|:---:|:---:|:---:|---|
| 100 | `Allow-MI-Management-9000` | TCP | `SqlManagement` | `*` | 9000 | ✅ Allow | SQL MI management vanuit Azure — service tag `SqlManagement` vereist |
| 101 | `Allow-MI-Management-9003` | TCP | `SqlManagement` | `*` | 9003 | ✅ Allow | SQL MI management poort 9003 — vereist voor deployment en beheer |
| 102 | `Allow-MI-Redirect-11000` | TCP | `SqlManagement` | `*` | 11000–11999 | ✅ Allow | SQL MI redirect connection poorten — gebruikt door client-applicaties |
| 103 | `Allow-MI-Redirect-14000` | TCP | `SqlManagement` | `*` | 14000–14999 | ✅ Allow | SQL MI redirect poorten alternatieve range |
| 110 | `Allow-HealthProbe` | TCP | `AzureLoadBalancer` | `*` | `*` | ✅ Allow | Azure Load Balancer health probes voor SQL MI HA-cluster |
| 120 | `Allow-Internal-Comms` | `*` | `10.20.4.0/24` | `10.20.4.0/24` | `*` | ✅ Allow | Interne communicatie tussen SQL MI cluster-nodes (primary + 2 secondary) |
| 130 | `Allow-SQL-from-Web` | TCP | `snet-spoke-data` | `*` | 1433 | ✅ Allow | SQL-verbindingen van Private Endpoint subnet naar SQL MI op poort 1433 |
| 140 | `Allow-SQL-Mgmt` | TCP | `snet-spoke-mgmt` | `*` | 1433 | ✅ Allow | DBA-toegang via jump VM in mgmt-subnet voor database-beheer |
| 4096 | `Deny-All-Inbound` | `*` | `*` | `*` | `*` | 🚫 Deny | Default deny — SQL MI alleen bereikbaar via gedefinieerde routes |

### Outbound

| Prioriteit | Naam | Protocol | Bron | Doel | Poort | Actie | Toelichting |
|:---:|---|:---:|---|:---:|:---:|:---:|---|
| 100 | `Allow-MI-Mgmt-Out-443` | TCP | `*` | `AzureCloud` | 443 | ✅ Allow | SQL MI management naar Azure Cloud (certificaten, telemetrie, updates) |
| 101 | `Allow-MI-Mgmt-Out-12000` | TCP | `*` | `AzureCloud` | 12000 | ✅ Allow | SQL MI management poort 12000 outbound naar Azure Cloud |
| 110 | `Allow-Internal-Out` | `*` | `10.20.4.0/24` | `10.20.4.0/24` | `*` | ✅ Allow | Interne cluster-communicatie outbound tussen SQL MI nodes |
| 120 | `Allow-SQL-Geo-Replication` | TCP | `*` | `10.20.4.0/24` | 5022 | ✅ Allow | Always On geo-replicatie naar secondary in North Europe via poort 5022 |
| 130 | `Allow-DNS` | UDP | `*` | `snet-hub-dns` | 53 | ✅ Allow | DNS-resolutie via Hub DNS Private Resolver |
| 4096 | `Deny-All-Outbound` | `*` | `*` | `*` | `*` | 🚫 Deny | Default deny — SQL MI communiceert enkel met gedefinieerde bestemmingen |

---

## nsg-mgmt

**Subnet:** `snet-spoke-mgmt` | **CIDR:** `10.20.5.0/27` | **Resource:** DevOps Agents · Jump VMs

> ℹ️ Beheer-subnet voor Azure DevOps self-hosted agents en jump VMs. Toegang verloopt uitsluitend via Azure Bastion — geen publieke IP-adressen op VMs. Outbound HTTPS gaat via Hub Firewall (UDR).

### Inbound

| Prioriteit | Naam | Protocol | Bron | Doel | Poort | Actie | Toelichting |
|:---:|---|:---:|---|:---:|:---:|:---:|---|
| 100 | `Allow-Bastion-RDP` | TCP | `AzureBastionSubnet` | `*` | 3389 | ✅ Allow | RDP-toegang via Azure Bastion voor Windows jump VMs — geen publiek IP |
| 110 | `Allow-Bastion-SSH` | TCP | `AzureBastionSubnet` | `*` | 22 | ✅ Allow | SSH-toegang via Azure Bastion voor Linux-gebaseerde agents |
| 120 | `Allow-AzureDevOps-Inbound` | TCP | `AzureCloud` | `*` | 443 | ✅ Allow | Azure DevOps service communiceert terug naar self-hosted agents |
| 4096 | `Deny-All-Inbound` | `*` | `*` | `*` | `*` | 🚫 Deny | Default deny — geen directe toegang van internet of andere subnetten |

### Outbound

| Prioriteit | Naam | Protocol | Bron | Doel | Poort | Actie | Toelichting |
|:---:|---|:---:|---|:---:|:---:|:---:|---|
| 100 | `Allow-DevOps-to-AzDO` | TCP | `*` | `AzureDevOps` | 443 | ✅ Allow | Self-hosted agents verbinden met Azure DevOps — service tag |
| 110 | `Allow-Mgmt-to-SQL` | TCP | `*` | `snet-spoke-data` | 1433 | ✅ Allow | DBA-toegang via jump VM naar SQL MI via Private Endpoint |
| 120 | `Allow-Mgmt-to-KV` | TCP | `*` | `snet-spoke-data` | 443 | ✅ Allow | Key Vault beheer (certificaten, secrets rotatie) via PE |
| 130 | `Allow-Mgmt-to-Storage` | TCP | `*` | `snet-spoke-data` | 443 | ✅ Allow | Blob Storage en Azure Files via PE voor beheer en deployment |
| 140 | `Allow-Mgmt-to-AzureMonitor` | TCP | `*` | `AzureMonitor` | 443 | ✅ Allow | Azure Monitor agent telemetrie vanuit DevOps agents en jump VMs |
| 150 | `Allow-Mgmt-to-Internet` | TCP | `*` | `Internet` | 443 | ✅ Allow | Outbound HTTPS via Hub Firewall voor package downloads en Azure CLI |
| 160 | `Allow-DNS` | UDP | `*` | `snet-hub-dns` | 53 | ✅ Allow | DNS-resolutie via Hub DNS Private Resolver |
| 4096 | `Deny-All-Outbound` | `*` | `*` | `*` | `*` | 🚫 Deny | Default deny — overig outbound via Hub Firewall (UDR) |

## private endpoints

Documenteer alle **Private Endpoints** in de architectuur:

## Overzicht

| # | PE naam | Resource | Type | Privé IP | Sub-resource | Private DNS Zone |
|:---:|---|---|---|---|---|---|
| 1 | `pe-sql-contoso-prd` | `sql-contoso-prd-001` | SQL Managed Instance | `10.20.3.4` | `managedInstance` | `privatelink.database.windows.net` |
| 2 | `pe-blob-contoso-prd` | `stcontoso001` | Storage Account (Blob) | `10.20.3.5` | `blob` | `privatelink.blob.core.windows.net` |
| 3 | `pe-kv-contoso-prd` | `kv-contoso-prd` | Key Vault | `10.20.3.6` | `vault` | `privatelink.vaultcore.azure.net` |
| 4 | `pe-sb-contoso-prd` | `sb-contoso-prd` | Service Bus | `10.20.3.7` | `namespace` | `privatelink.servicebus.windows.net` |
| 5 | `pe-app-contoso-prd` | `web-contoso-prd` | App Service | `10.20.3.8` | `sites` | `privatelink.azurewebsites.net` |

> **Azure reserveert 5 IPs per subnet** (`.0` network · `.1` gateway · `.2`+`.3` DNS · `.255` broadcast).
> Eerste bruikbare IP in `10.20.3.0/24` is `10.20.3.4` → PE-adressen starten vanaf `.4`.

### waarom private endpoints?
Documenteer in 3–5 zinnen waarom je Private Endpoints gebruikt in plaats van Service Endpoints. Wat zijn de voordelen en nadelen?

Private endpoints geven een prive-IP adres in het vnet, daardoor zijn ze publiek niet toegankelijk waardoor ze veiliger zijn voor aanvallen van buitenaf.
Ze werken ook goed voor verbindingen van On-premises,omdat alles via DNS en VPN naar het interne IP gaat. Het nadeel is dat ze meer kosten en extra werk geven om uw DNS en Private iP te beheren.
---

## Private DNS Zones

Elke Private Endpoint vereist een bijhorende Private DNS Zone voor correcte naamresolutie. Alle zones zijn gelinkt aan het **Hub VNet** (`10.0.0.0/16`) zodat alle gepeerde spokes dezelfde resolutie hebben.

| Private DNS Zone | Gekoppeld aan | PE resource |
|---|---|---|
| `privatelink.database.windows.net` | Hub VNet | SQL Managed Instance |
| `privatelink.blob.core.windows.net` | Hub VNet | Storage Account (Blob) |
| `privatelink.vaultcore.azure.net` | Hub VNet | Key Vault |
| `privatelink.servicebus.windows.net` | Hub VNet | Service Bus |
| `privatelink.azurewebsites.net` | Hub VNet | App Service |

**Waarom aan Hub VNet koppelen?**

In een Hub-Spoke topologie worden Private DNS Zones **altijd** gekoppeld aan het Hub VNet — niet aan individuele spokes. De Azure DNS Private Resolver in `snet-hub-dns` (`10.0.3.0/28`) stuurt DNS-queries van alle spokes door via het Hub VNet, waardoor alle zones automatisch beschikbaar zijn vanuit elk spoke-netwerk.

## DNS-resolutie flow

```
App Service (web-contoso-prd) vraagt verbinding met SQL MI
│
├─ Stap 1: DNS query voor "sql-contoso-prd-001.database.windows.net"
│
├─ Stap 2: Azure DNS (168.63.129.16) stuurt door naar
│          DNS Private Resolver inbound endpoint (snet-hub-dns)
│
├─ Stap 3: Resolver zoekt in Private DNS Zone
│          "privatelink.database.windows.net" (gelinkt aan Hub VNet)
│
├─ Stap 4: A-record gevonden:
│          sql-contoso-prd-001.privatelink.database.windows.net → 10.20.3.4
│
└─ Stap 5: TCP verbinding naar 10.20.3.4:1433
           Verkeer blijft intern (VNet → PE → SQL MI subnet)
           Nooit via publiek internet ✅
```

> ⚠️ **Zonder Private DNS Zone** lost `sql-contoso-prd-001.database.windows.net` op naar het **publieke IP** van SQL MI — ook al is publieke toegang uitgeschakeld. Dit resulteert in een verbindingsfout. De DNS Zone is dus geen optie maar een **vereiste**.
```

**Vul in**: Teken dit diagram netter en documenteer welke DNS-forwarder-configuratie nodig is op DC01.
## Waarom DNS forwarding op DC01?

In een Hub-Spoke topologie lost Azure DNS (`168.63.129.16`) Private DNS Zones automatisch
op **binnen** het VNet. On-premises systemen bereiken dit adres echter niet — het is een
Azure-intern virtual IP dat niet routeerbaar is over VPN.

Zonder forwarder configuratie op DC01 gebeurt het volgende voor on-premises clients:

```
DC01 Gent probeert: sql-contoso-prd-001.database.windows.net
└─ Stuurt query naar publieke DNS (8.8.8.8 of ISP-resolver)
     └─ Ontvangt publiek Azure IP (40.x.x.x)
          └─ TCP verbinding naar publiek IP → GEWEIGERD
             (publicDataEndpointEnabled = false op SQL MI)
```

Met forwarder configuratie:

```
DC01 Gent probeert: sql-contoso-prd-001.database.windows.net
└─ Conditional forwarder: *.database.windows.net → DNS Private Resolver (10.0.3.x)
     └─ Resolver zoekt in Private DNS Zone (Hub VNet)
          └─ A-record: 10.20.3.4
               └─ TCP verbinding via VPN-tunnel → PE 10.20.3.4:1433 ✅
```

---

## Architectuur DNS-resolutie

```
ON-PREMISES                          AZURE HUB (10.0.0.0/16)
─────────────────                    ──────────────────────────────────────
DC01 Gent                            DNS Private Resolver
192.168.1.10 (PDC)                   snet-hub-dns  10.0.3.0/28
│                                    │
│  Conditional Forwarders:           │  Inbound endpoint:  10.0.3.4
│  *.database.windows.net     ──────►│  Outbound endpoint: 10.0.3.5
│  *.blob.core.windows.net    ──────►│
│  *.vaultcore.azure.net      ──────►│       ▼
│  *.servicebus.windows.net   ──────►│  Private DNS Zones (gelinkt aan Hub)
│  *.azurewebsites.net        ──────►│  privatelink.database.windows.net
│                                    │    └─ A: sql-contoso-prd-001 → 10.20.3.4
│  Alle andere queries:              │  privatelink.blob.core.windows.net
│  → contoso.local (AD DS)           │    └─ A: stcontoso001 → 10.20.3.5
│  → 8.8.8.8 / ISP (internet)       │  privatelink.vaultcore.azure.net
                                     │    └─ A: kv-contoso-prd → 10.20.3.6
                                     │  privatelink.servicebus.windows.net
                                     │    └─ A: sb-contoso-prd → 10.20.3.7
                                     │  privatelink.azurewebsites.net
                                     │    └─ A: web-contoso-prd → 10.20.3.8
                                     
<img width="1562" height="881" alt="dns-flow-diagram_final" src="https://github.com/user-attachments/assets/116c3ad4-514d-4bc8-8708-5e402e54c533" />


---

6. azure firewall regels

Documenteer de **minimaal vereiste Azure Firewall regels**:

## RC-NAT-Inbound — DNAT regels

**Type:** DNAT | **Doel:** inkomend publiek verkeer omzetten naar interne resources

> ℹ️ De Application Gateway (`agw-contoso-prd-001`) heeft een **eigen publiek IP** (`pip-agw-prd`).
> Extern HTTPS-verkeer van gebruikers gaat direct naar de AGW — niet via het Firewall-IP.
> DNAT is hier beschikbaar als alternatief routing-pad.

| Prio | Naam | Protocol | Bron | Doel | Poort | Actie |
|:---:|---|:---:|---|---|:---:|---|
| 100 | `DNAT-HTTPS-to-AGW` | TCP | Internet (`*`) | pip-agw-prd | 443 | DNAT → 10.20.0.4 |

---

## RC-NET-HubSpoke — Network regels

**Type:** Network | **Doel:** IP/poort-gebaseerde filtering voor VNet-naar-VNet en VPN-verkeer

| Prio | Naam | Protocol | Bron | Doel | Poort | Actie | Toelichting |
|:---:|---|:---:|---|---|:---:|:---:|---|
| 100 | `NET-Allow-DNS-Spoke-to-Hub` | UDP | `10.10.0.0/16`, `10.20.0.0/16` | `10.0.3.4` | 53 | ✅ Allow | DNS-queries van Spoke-Prod en NonProd naar DNS Private Resolver |
| 110 | `NET-Allow-DNS-OnPrem-to-Hub` | UDP | `192.168.0.0/16` | `10.0.3.4` | 53 | ✅ Allow | DNS Conditional Forwarder op DC01 stuurt via VPN naar Resolver |
| 120 | `NET-Allow-SQL-Spoke-to-SQLI` | TCP | `10.10.1.0/24`, `10.10.2.0/27` | `10.10.4.0/24` | 1433 | ✅ Allow | App Service en Functions naar SQL MI via UDR door Firewall |
| 130 | `NET-Allow-SQL-OnPrem` | TCP | `192.168.0.0/16` | `10.10.3.4` | 1433 | ✅ Allow | On-premises SAP ERP verbindt via VPN naar SQL MI Private Endpoint |
| 140 | `NET-Allow-RDP-SSH-Bastion` | TCP | `10.0.2.0/27` | `10.10.0.0/16`, `10.40.0.0/24` | 22, 3389 | ✅ Allow | Azure Bastion naar VMs in Spoke en Identity subnet |
| 150 | `NET-Allow-LDAP-DC-Replication` | TCP/UDP | `192.168.1.0/24` | `10.40.0.0/27` | 53, 88, 135, 389, 445, 464, 636, 3268 | ✅ Allow | AD DS replicatie on-prem DC01 → Azure vm-dc-01/02 |
| 160 | `NET-Allow-NTP` | UDP | `10.40.0.0/27` | `168.63.129.16` | 123 | ✅ Allow | DC-replica VMs synchroniseren tijd via Azure NTP |
| 170 | `NET-Allow-AMQP-ServiceBus` | TCP | `10.10.1.0/24`, `10.10.2.0/27` | `10.10.3.7` | 5671, 5672 | ✅ Allow | AMQP naar Service Bus Private Endpoint |
| 180 | `NET-Allow-VPN-BGP` | TCP | `10.0.1.0/27` | `192.168.1-3.0/24` | 179 | ✅ Allow | BGP-peering VPN Gateway ↔ on-premises routers |
| 190 | `NET-Allow-Spoke-to-Spoke-Restricted` | TCP | `10.20.0.0/16` | `10.10.0.0/16` | 443, 1433 | ✅ Allow | NonProd → Prod beperkt tot HTTPS en SQL (DevOps agents) |
| 9999 | `NET-Deny-All` | `*` | `*` | `*` | `*` | 🚫 Deny | Default deny-all — maakt impliciete deny zichtbaar in logs |

### AD DS replicatie — poorten tabel

| Poort | Protocol | Dienst |
|:---:|:---:|---|
| 53 | TCP/UDP | DNS |
| 88 | TCP/UDP | Kerberos authenticatie |
| 135 | TCP | RPC Endpoint Mapper |
| 389 | TCP/UDP | LDAP |
| 445 | TCP | SMB (SYSVOL/NETLOGON replicatie) |
| 464 | TCP/UDP | Kerberos wachtwoordwijziging |
| 636 | TCP | LDAPS (versleuteld LDAP) |
| 3268 | TCP | Global Catalog |

---

## RC-APP-Egress — Application regels

**Type:** Application | **Doel:** FQDN-filtering voor uitgaand HTTPS-verkeer via TLS-inspectie

> ⚠️ Application rules vereisen dat Azure Firewall als **DNS-proxy** is ingesteld.
> FQDN-matching werkt op het SNI-veld na TLS-terminatie door Firewall Premium.
> Stel in: Firewall Policy → DNS Settings → DNS Proxy = Enabled, DNS server = `10.0.3.4`.

| Prio | Naam | Protocol | Bron | Doel (FQDN) | Poort | Actie |
|:---:|---|:---:|---|---|:---:|:---:|
| 100 | `APP-Allow-AzureUpdate` | HTTPS | `10.40.0.0/27` | `WindowsUpdate` *(service tag)* | 443 | ✅ Allow |
| 110 | `APP-Allow-AzureMonitor` | HTTPS | `10.10.0.0/16`, `10.40.0.0/24` | `*.monitor.azure.com`, `*.applicationinsights.io`, `*.ods.opinsights.azure.com` | 443 | ✅ Allow |
| 120 | `APP-Allow-AzureDefender` | HTTPS | `10.10.0.0/16`, `10.40.0.0/24` | `*.security.microsoft.com`, `*.blob.core.windows.net` | 443 | ✅ Allow |
| 130 | `APP-Allow-AzureDevOps` | HTTPS | `10.10.5.0/27` | `*.dev.azure.com`, `*.vsassets.io`, `*.visualstudio.com` | 443 | ✅ Allow |
| 140 | `APP-Allow-ContainerRegistry` | HTTPS | `10.10.5.0/27` | `*.azurecr.io`, `mcr.microsoft.com` | 443 | ✅ Allow |
| 150 | `APP-Allow-PackageManagers` | HTTPS | `10.10.5.0/27` | `*.nuget.org`, `*.npmjs.com`, `pypi.org`, `github.com` | 443 | ✅ Allow |
| 160 | `APP-Allow-EntraID` | HTTPS | `10.10.0.0/16`, `10.40.0.0/24` | `login.microsoftonline.com`, `login.microsoft.com`, `*.identity.azure.com` | 443 | ✅ Allow |
| 170 | `APP-Allow-KeyVault-Mgmt` | HTTPS | `10.10.0.0/16`, `10.40.0.0/24` | `*.vault.azure.net` | 443 | ✅ Allow |
| 180 | `APP-Allow-SAP-Integration` | HTTPS | `10.10.2.0/27` | `sap.contoso.local` | 443, 8080 | ✅ Allow |
| 190 | `APP-Allow-CommunicationServices` | HTTPS | `10.10.1.0/24` | `*.communication.azure.com` | 443 | ✅ Allow |
| 200 | `APP-Allow-GitHubActions` | HTTPS | `10.10.5.0/27` | `api.github.com`, `github.com` | 443 | ✅ Allow |
| 9999 | `APP-Deny-All` | HTTPS/HTTP | `*` | `*` | 80, 443 | 🚫 Deny |


DNAT: geen — inbound verkeer gaat via Application Gateway WAF v2 (pip-agw-prd), Azure Firewall is enkel voor egress en east-west verkeer.

AD Replication en DC-RPC zijn nodig zodat de domain controller in Azure kan blijven synchroniseren met de on-prem DC in Gent. Zonder deze regels stopt Entra Connect en werkt AD-authenticatie niet meer bij VPN-uitval.
SqlMI-Management is nodig voor SQL Managed Instance om met Azure beheerdiensten te communiceren via de service tag. Dit werkt samen met de route die SQL management verkeer buiten de firewall om laat lopen
---
8.Vpn of expressRoute? 
| Verkeerstype             | Wat gebeurt er?                     | Volume          | Belang        |
| ------------------------ | ----------------------------------- | --------------- | ------------- |
| AD-replicatie            | Sync tussen DC01 (Gent) en Azure DC | Laag            | Kritisch      |
| Entra Connect            | Identiteitssync naar Microsoft 365  | Zeer laag       | Kritisch      |
| SAP calls                | Periodieke API/SOAP calls           | Laag (MB’s/dag) | Belangrijk    |
| Beheer (Bastion/RDP/SSH) | Admin toegang tot servers           | Laag            | Operationeel  |
| DNS queries              | Via Private DNS Resolver            | Minimaal        | Ondersteunend |


👉 Geen gebruikersverkeer en geen grote databundels gaan door de VPN.

VPN vs ExpressRoute
| Aspect           | VPN Gateway (huidig)           | ExpressRoute                            |
| ---------------- | ------------------------------ | --------------------------------------- |
| Type verbinding  | Over internet (versleuteld)    | Privé dedicated lijn                    |
| Bandbreedte      | ±650 Mbps (meer dan voldoende) | 50 Mbps tot multi-Gbps                  |
| Gebruik Contoso  | Alleen beheer + synchronisatie | Grote datastromen en kritieke workloads |
| Latency          | ~8–15 ms                       | Lager en stabieler (minder jitter)      |
| Kost             | ±€180/maand                    | ±€500–€1800/maand                       |
| Complexiteit     | Laag                           | Hoog                                    |
| Nood bij Contoso | ✔ Volstaat                     | ❌ Niet nodig in huidige situatie        |

Voordelen & nadelen

VPN Gateway (gekozen)
✔ Goedkoop en snel te implementeren
✔ Meer dan genoeg voor beheerverkeer
✔ Minder complex (geen carrier nodig)
✖ Minder geschikt voor grote datastromen
✖ Minder “enterprise-grade” dan ExpressRoute

ExpressRoute
✔ Zeer stabiel en voorspelbaar netwerk
✔ Hoge bandbreedte mogelijk
✔ Geen internetpad
✖ Duur
✖ Alleen nuttig bij zware productie-data

Conclusie (belangrijk)

Er is gekozen voor VpnGw2 omdat Contoso enkel beheer- en synchronisatieverkeer over de tunnel stuurt en vpngw2 een max doorvoer van 1 Gbps geeft.De VpnGw1 zal in ons geval te weinig doorvoer hebben, bij een gelijktijdige backup van de drie sites zouden het al beginnen knellen. De bandbreedte en latency van VPNGw2 zijn ruim voldoende en veel goedkoper dan ExpressRoute, waardoor een dedicated circuit geen meerwaarde heeft in deze fase.

De hub-spoke setup en gateway subnet zijn al voorbereid zodat ExpressRoute later eenvoudig kan worden toegevoegd als SAP of andere workloads naar Azure verhuizen of als er grote datastromen bijkomen.
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
