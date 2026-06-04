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

NSG: nsg-func (snet-spoke-func 10.20.5.0/27)
AppServiceManagement op poort 454/455 is verplicht — zonder deze regel gaan Function App-instanties offline. Poort 5672 is toegevoegd naast 5671 omdat de Service Bus trigger-SDK beide AMQP-poorten kan gebruiken.
| Prioriteit | Naam                  | Richting | Protocol | Bron                 | Doel                       | Poort         | Actie |
| ---------- | --------------------- | -------- | -------- | -------------------- | -------------------------- | ------------- | ----- |
| 100        | Allow-AGW-to-Func     | Inbound  | TCP      | 10.20.0.0/27         | `*`                        | 443           | Allow |
| 110        | Allow-AppSvcMgmt      | Inbound  | TCP      | AppServiceManagement | `*`                        | 454,455       | Allow |
| 4096       | Deny-All-Inbound      | Inbound  | `*`      | `*`                  | `*`                        | `*`           | Deny  |
| 200        | Allow-Func-to-SQL     | Outbound | TCP      | `*`                  | 10.20.4.4/32               | 1433          | Allow |
| 210        | Allow-Func-to-Storage | Outbound | TCP      | `*`                  | 10.20.2.5/32               | 443           | Allow |
| 220        | Allow-Func-to-KV      | Outbound | TCP      | `*`                  | 10.20.3.4/32               | 443           | Allow |
| 230        | Allow-Func-to-SB      | Outbound | TCP      | `*`                  | 10.20.2.7/32               | 443,5671,5672 | Allow |
| 240        | Allow-Func-to-SAP     | Outbound | TCP      | `*`                  | 192.168.1.20/32            | 443,8080,3300 | Allow |
| 250        | Allow-Func-to-CommSvc | Outbound | TCP      | `*`                  | AzureCommunicationServices | 443           | Allow |
| 260        | Allow-Func-to-DNS     | Outbound | UDP      | `*`                  | 168.63.129.16/32           | 53            | Allow |
| 270        | Allow-Func-to-Azure   | Outbound | TCP      | `*`                  | AzureCloud                 | 443           | Allow |
| 4096       | Deny-All-Outbound     | Outbound | `*`      | `*`                  | `*`                        | `*`           | Deny  |
---
NSG: nsg-data — snet-spoke-data 10.20.2.0/24 (Private Endpoints: Storage · Service Bus)
| Prioriteit | Naam                    | Richting | Protocol | Bron           | Doel         | Poort           | Actie |
| ---------- | ----------------------- | -------- | -------- | -------------- | ------------ | --------------- | ----- |
| 100        | Allow-App-to-Blob-PE    | Inbound  | TCP      | 10.20.1.0/24   | 10.20.2.5/32 | 443             | Allow |
| 110        | Allow-Func-to-Blob-PE   | Inbound  | TCP      | 10.20.5.0/27   | 10.20.2.5/32 | 443             | Allow |
| 120        | Allow-App-to-File-PE    | Inbound  | TCP      | 10.20.1.0/24   | 10.20.2.6/32 | 443             | Allow |
| 130        | Allow-App-to-SB-PE      | Inbound  | TCP      | 10.20.1.0/24   | 10.20.2.7/32 | 443, 5671       | Allow |
| 140        | Allow-Func-to-SB-PE     | Inbound  | TCP      | 10.20.5.0/27   | 10.20.2.7/32 | 443, 5671, 5672 | Allow |
| 150        | Allow-Onprem-to-Storage | Inbound  | TCP      | 192.168.0.0/16 | 10.20.2.5/32 | 443             | Allow |
| 4096       | Deny-All-Inbound        | Inbound  | *        | *              | *            | *               | Deny  |
## private endpoints

Documenteer alle **Private Endpoints** in de architectuur:

| Resource | Private Endpoint naam | Subnet | DNS Zone |
|---|---|---|---|
| Resource               | Private Endpoint naam   | Subnet              | DNS Zone                           |
| ---------------------- | ----------------------- | ------------------- | ---------------------------------- |
| SQL Managed Instance   | pep-sqlmi-contoso-prd   | snet-spoke-sqlmi    | privatelink.database.windows.net   |
| Storage Account (blob) | pep-st-blob-contoso-prd | snet-spoke-data     | privatelink.blob.core.windows.net  |
| Storage Account (file) | pep-st-file-contoso-prd | snet-spoke-data     | privatelink.file.core.windows.net  |
| Key Vault              | pep-kv-contoso-prd      | snet-spoke-security | privatelink.vaultcore.azure.net    |
| Service Bus            | pep-sb-contoso-prd      | snet-spoke-data     | privatelink.servicebus.windows.net |
| App Service (web)      | pep-web-contoso-prd     | snet-spoke-app      | privatelink.azurewebsites.net      |
| App Service (api)      | pep-api-contoso-prd     | snet-spoke-app      | privatelink.azurewebsites.net      |

### waarom private endpoints?
Documenteer in 3–5 zinnen waarom je Private Endpoints gebruikt in plaats van Service Endpoints. Wat zijn de voordelen en nadelen?

### Private endpoints geven een prive-IP adres in het vnet, daardoor zijn ze publiek niet toegankelijk waardoor ze veiliger zijn voor aanvallen van buitenaf.
### Ze werken ook goed voor verbindingen van On-premises,omdat alles via DNS en VPN naar het interne IP gaat. Het nadeel is dat ze meer kosten en extra werk geven om uw DNS en Private iP te beheren.
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
<img width="1472" height="1480" alt="image" src="https://github.com/user-attachments/assets/c9856861-07f9-4416-853d-36df71a8cf95" />

---

6. azure firewall regels

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

Contoso applicatie
| Naam                | Bron         | Protocol             | Target FQDN                                                                 | Actie |
| ------------------- | ------------ | -------------------- | --------------------------------------------------------------------------- | ----- |
| Allow-WindowsUpdate | 10.20.0.0/16 | HTTPS:443            | *.update.microsoft.com, *.windowsupdate.com                                 | Allow |
| Allow-AzureMonitor  | 10.20.0.0/16 | HTTPS:443            | *.monitor.azure.com, *.ods.opinsights.azure.com, *.oms.opinsights.azure.com | Allow |
| Allow-AzureAD       | 10.20.0.0/16 | HTTPS:443            | login.microsoftonline.com, *.microsoftonline.com, graph.microsoft.com       | Allow |
| Allow-SAP-API       | 10.20.0.0/16 | HTTPS:443, HTTP:8080 | sap-api.contoso.local, sap.contoso.be                                       | Allow |
| Allow-CommServices  | 10.20.0.0/16 | HTTPS:443            | *.communication.azure.com                                                   | Allow |
| Allow-KV-CRL        | 10.20.0.0/16 | HTTP:80, HTTPS:443   | crl.microsoft.com, ocsp.msocsp.com                                          | Allow |
| Allow-EntraConnect  | 10.40.0.0/24 | HTTPS:443            | *.msappproxy.net, *.servicebus.windows.net                                  | Allow |
| Allow-DevOps-Agents | 10.20.4.0/27 | HTTPS:443            | *.dev.azure.com, *.visualstudio.com, *.vsblob.visualstudio.com              | Allow |
| Deny-All-App        | *            | *                    | *                                                                           | Deny  |


---
| Naam                   | Bron           | Protocol | Doel            | Poort                 | Actie |
| ---------------------- | -------------- | -------- | --------------- | --------------------- | ----- |
| Allow-Onprem-to-AGW    | 192.168.0.0/16 | TCP      | 10.20.0.0/27    | 443                   | Allow |
| Allow-Onprem-to-SQL    | 192.168.0.0/16 | TCP      | 10.20.4.4/32    | 1433                  | Allow |
| Allow-Onprem-to-KV     | 192.168.0.0/16 | TCP      | 10.20.3.4/32    | 443                   | Allow |
| Allow-Onprem-to-Mgmt   | 192.168.0.0/16 | TCP      | 10.20.4.0/27    | 22, 3389              | Allow |
| Allow-Azure-to-SAP     | 10.20.0.0/16   | TCP      | 192.168.1.20/32 | 443, 8080, 3300       | Allow |
| Allow-AD-Replication   | 10.40.0.0/24   | TCP/UDP  | 192.168.1.10/32 | 389, 636, 53, 88, 445 | Allow |
| Allow-DC-RPC           | 10.40.0.0/24   | TCP      | 192.168.0.0/16  | 49152–65535           | Allow |
| Allow-SqlMI-Management | 10.20.4.0/24   | TCP      | SqlManagement   | 80, 443, 12000        | Allow |
| Allow-NTP              | 10.20.0.0/16   | UDP      | 40.119.6.228/32 | 123                   | Allow |
| Deny-All-Net           | *              | *        | *               | *                     | Deny  |


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

Er is gekozen voor VpnGw1 omdat Contoso enkel beheer- en synchronisatieverkeer over de tunnel stuurt. De bandbreedte en latency van VPN zijn ruim voldoende en veel goedkoper dan ExpressRoute, waardoor een dedicated circuit geen meerwaarde heeft in deze fase.

Op het diagram staat toch ExpressRoute getekend omdat de architectuur future-ready is: de hub-spoke setup en gateway subnet zijn al voorbereid zodat ExpressRoute later eenvoudig kan worden toegevoegd als SAP of andere workloads naar Azure verhuizen of als er grote datastromen bijkomen.
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
