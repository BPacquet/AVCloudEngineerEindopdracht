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
<mxfile host="Electron">
  <diagram id="app-lz-v1" name="Application Landing Zone — Contoso Prod">
    <mxGraphModel dx="1740" dy="885" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="2400" pageHeight="1700" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="title" parent="1" style="text;html=1;align=center;fontSize=20;fontStyle=1;fillColor=#dae8fc;strokeColor=#6c8ebf;rounded=1;" value="Application Landing Zone — Contoso Manufacturing (Prod)" vertex="1">
          <mxGeometry height="46" width="900" x="500" y="20" as="geometry" />
        </mxCell>
        <mxCell id="subtitle" parent="1" style="text;html=1;align=center;fontSize=11;fillColor=none;strokeColor=none;fontColor=#666666;" value="Subscription: Contoso-Prod  |  Spoke VNet: 10.20.0.0/16  |  Corp Management Group  |  ALZ Hub-and-Spoke" vertex="1">
          <mxGeometry height="20" width="900" x="500" y="68" as="geometry" />
        </mxCell>
        <mxCell id="internet-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;strokeWidth=2;fontSize=14;fontStyle=1;dashed=1;" value="&amp;nbsp; &amp;nbsp;Internet" vertex="1">
          <mxGeometry height="46" width="160" x="870" y="110" as="geometry" />
        </mxCell>
        <mxCell id="afd-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;strokeWidth=2;fontSize=13;fontStyle=1;" value="Azure Front Door" vertex="1">
          <mxGeometry height="46" width="280" x="810" y="200" as="geometry" />
        </mxCell>
        <mxCell id="afd-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="Global LB  |  CDN  |  DDoS Protection Standard  |  WAF Policy" vertex="1">
          <mxGeometry height="16" width="280" x="810" y="246" as="geometry" />
        </mxCell>
        <mxCell id="afd-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;fontSize=12;image=img/lib/azure2/networking/Front_Doors.svg;" value="" vertex="1">
          <mxGeometry height="24" width="27" x="812" y="208" as="geometry" />
        </mxCell>
        <mxCell id="e-inet-afd" edge="1" parent="1" source="internet-box" style="edgeStyle=orthogonalEdgeStyle;strokeColor=#b85450;strokeWidth=2;dashed=1;" target="afd-box" value="">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="sub-outer" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e8f4fd;strokeColor=#0050ef;strokeWidth=3;arcSize=2;" value="" vertex="1">
          <mxGeometry height="1340" width="1780" x="60" y="290" as="geometry" />
        </mxCell>
        <mxCell id="sub-title" parent="1" style="text;html=1;align=left;fontSize=16;fontStyle=1;fontColor=#003399;" value="Contoso-Prod" vertex="1">
          <mxGeometry height="24" width="300" x="80" y="298" as="geometry" />
        </mxCell>
        <mxCell id="sub-sub" parent="1" style="text;html=1;align=left;fontSize=11;fontColor=#0050ef;" value="Subscription" vertex="1">
          <mxGeometry height="18" width="200" x="80" y="320" as="geometry" />
        </mxCell>
        <mxCell id="sub-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;fontSize=12;image=img/lib/azure2/general/Subscriptions.svg;" value="" vertex="1">
          <mxGeometry height="39" width="30" x="360" y="300" as="geometry" />
        </mxCell>
        <mxCell id="sub-policy" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;fontSize=9;dashed=1;" value="Corp Policy: Require VNet integration  |  Deny Public IP  |  Private endpoints only voor PaaS  |  No outbound internet direct  |  Budget Alert 80%/100%" vertex="1">
          <mxGeometry height="22" width="1740" x="80" y="344" as="geometry" />
        </mxCell>
        <mxCell id="spoke-outer" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#cce5ff;strokeColor=#0050ef;strokeWidth=2;dashed=1;arcSize=2;" value="" vertex="1">
          <mxGeometry height="1220" width="1600" x="80" y="378" as="geometry" />
        </mxCell>
        <mxCell id="spoke-title" parent="1" style="text;html=1;align=left;fontSize=13;fontStyle=1;fontColor=#003399;" value="Spoke VNet — 10.20.0.0/16" vertex="1">
          <mxGeometry height="20" width="400" x="100" y="386" as="geometry" />
        </mxCell>
        <mxCell id="spoke-peering-note" parent="1" style="text;html=1;align=right;fontSize=9;fontColor=#378ADD;fontStyle=2;" value="VNet Peering → Hub VNet (10.0.0.0/16)  |  UDR: al het verkeer via Azure Firewall Premium" vertex="1">
          <mxGeometry height="18" width="760" x="900" y="386" as="geometry" />
        </mxCell>
        <mxCell id="sn-appgw-outer" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;strokeWidth=2;arcSize=3;" value="" vertex="1">
          <mxGeometry height="170" width="1560" x="100" y="416" as="geometry" />
        </mxCell>
        <mxCell id="sn-appgw-label" parent="1" style="text;html=1;align=left;fontSize=10;fontStyle=1;fontColor=#2d6a1e;" value="snet-spoke-appgw  —  10.20.0.0/27  |  ✅ NSG  |  32 IPs (27 bruikbaar)" vertex="1">
          <mxGeometry height="18" width="600" x="118" y="424" as="geometry" />
        </mxCell>
        <mxCell id="sn-appgw-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/networking/Subnet.svg;" value="" vertex="1">
          <mxGeometry height="23" width="34" x="840" y="424" as="geometry" />
        </mxCell>
        <mxCell id="appgw-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#006EAF;strokeWidth=2;fontSize=12;fontStyle=1;" value="Application Gateway v2" vertex="1">
          <mxGeometry height="46" width="340" x="118" y="448" as="geometry" />
        </mxCell>
        <mxCell id="appgw-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="L7 load balancing  |  SSL offload  |  URL-path routing  |  Health probes" vertex="1">
          <mxGeometry height="16" width="340" x="118" y="494" as="geometry" />
        </mxCell>
        <mxCell id="appgw-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/networking/Application_Gateways.svg;" value="" vertex="1">
          <mxGeometry height="32" width="32" x="120" y="456" as="geometry" />
        </mxCell>
        <mxCell id="waf-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;strokeWidth=2;fontSize=12;fontStyle=1;" value="WAF Policy" vertex="1">
          <mxGeometry height="46" width="220" x="490" y="448" as="geometry" />
        </mxCell>
        <mxCell id="waf-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="OWASP 3.2  |  Custom rules  |  Bot protection" vertex="1">
          <mxGeometry height="16" width="220" x="490" y="494" as="geometry" />
        </mxCell>
        <mxCell id="waf-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/networking/Web_Application_Firewall_Policies_WAF.svg;" value="" vertex="1">
          <mxGeometry height="32" width="32" x="492" y="454" as="geometry" />
        </mxCell>
        <mxCell id="nsg-appgw" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;fontSize=9;" value="NSG: allow 65200-65535 inbound (health), allow 443 from internet" vertex="1">
          <mxGeometry height="28" width="480" x="750" y="448" as="geometry" />
        </mxCell>
        <mxCell id="udr-appgw" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;fontSize=9;" value="UDR: 0.0.0.0/0 → Azure Firewall" vertex="1">
          <mxGeometry height="28" width="480" x="750" y="484" as="geometry" />
        </mxCell>
        <mxCell id="e-afd-appgw" edge="1" parent="1" source="afd-box" style="edgeStyle=orthogonalEdgeStyle;strokeColor=#006EAF;strokeWidth=2;" target="appgw-box" value="HTTPS">
          <mxGeometry relative="1" as="geometry">
            <Array as="points">
              <mxPoint x="950" y="270" />
              <mxPoint x="288" y="270" />
              <mxPoint x="288" y="416" />
            </Array>
          </mxGeometry>
        </mxCell>
        <mxCell id="sn-web-outer" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;strokeWidth=2;arcSize=3;" value="" vertex="1">
          <mxGeometry height="200" width="1560" x="100" y="606" as="geometry" />
        </mxCell>
        <mxCell id="sn-web-label" parent="1" style="text;html=1;align=left;fontSize=10;fontStyle=1;fontColor=#2d6a1e;" value="snet-spoke-web  —  10.20.1.0/24  |  ✅ NSG  |  256 IPs (251 bruikbaar)  |  App Service VNet Integration" vertex="1">
          <mxGeometry height="18" width="700" x="118" y="614" as="geometry" />
        </mxCell>
        <mxCell id="sn-web-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/networking/Subnet.svg;" value="" vertex="1">
          <mxGeometry height="23" width="34" x="840" y="610" as="geometry" />
        </mxCell>
        <mxCell id="asp-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#2d8a4e;strokeWidth=2;fontSize=12;fontStyle=1;" value="App Service Plan" vertex="1">
          <mxGeometry height="40" width="200" x="118" y="638" as="geometry" />
        </mxCell>
        <mxCell id="asp-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="P2v3  |  Linux / Windows  |  Auto-scale" vertex="1">
          <mxGeometry height="16" width="200" x="118" y="678" as="geometry" />
        </mxCell>
        <mxCell id="appservice-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#006EAF;strokeWidth=2;fontSize=12;fontStyle=1;" value="App Service (Frontend)" vertex="1">
          <mxGeometry height="40" width="280" x="348" y="638" as="geometry" />
        </mxCell>
        <mxCell id="appservice-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="ASP.NET 8  |  VNet Integration  |  Managed Identity  |  HTTPS only" vertex="1">
          <mxGeometry height="16" width="280" x="348" y="678" as="geometry" />
        </mxCell>
        <mxCell id="appservice-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/app_services/App_Services.svg;" value="" vertex="1">
          <mxGeometry height="26" width="26" x="350" y="644" as="geometry" />
        </mxCell>
        <mxCell id="slot-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f0fff0;strokeColor=#2d8a4e;strokeWidth=1;fontSize=10;dashed=1;" value="Deployment Slot (staging)" vertex="1">
          <mxGeometry height="40" width="220" x="660" y="638" as="geometry" />
        </mxCell>
        <mxCell id="slot-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="Blue/green deployment  |  Swap met prod" vertex="1">
          <mxGeometry height="16" width="220" x="660" y="678" as="geometry" />
        </mxCell>
        <mxCell id="nsg-web" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;fontSize=9;" value="NSG: deny inbound from internet, allow from AppGW subnet (10.20.0.0/27), allow from VNet" vertex="1">
          <mxGeometry height="28" width="720" x="920" y="638" as="geometry" />
        </mxCell>
        <mxCell id="udr-web" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;fontSize=9;" value="UDR: 0.0.0.0/0 → Azure Firewall  |  Forced tunneling" vertex="1">
          <mxGeometry height="28" width="720" x="920" y="674" as="geometry" />
        </mxCell>
        <mxCell id="e-appgw-web" edge="1" parent="1" source="appgw-box" style="edgeStyle=orthogonalEdgeStyle;strokeColor=#006EAF;strokeWidth=2;" target="appservice-box" value="HTTP(S)">
          <mxGeometry relative="1" as="geometry">
            <Array as="points">
              <mxPoint x="288" y="590" />
              <mxPoint x="488" y="590" />
            </Array>
          </mxGeometry>
        </mxCell>
        <mxCell id="sn-func-outer" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;strokeWidth=2;arcSize=3;" value="" vertex="1">
          <mxGeometry height="220" width="1560" x="100" y="826" as="geometry" />
        </mxCell>
        <mxCell id="sn-func-label" parent="1" style="text;html=1;align=left;fontSize=10;fontStyle=1;fontColor=#2d6a1e;" value="snet-spoke-func  —  10.20.2.0/27  |  ✅ NSG  |  32 IPs (27 bruikbaar)  |  Functions VNet Integration" vertex="1">
          <mxGeometry height="18" width="700" x="118" y="834" as="geometry" />
        </mxCell>
        <mxCell id="sn-func-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/networking/Subnet.svg;" value="" vertex="1">
          <mxGeometry height="23" width="34" x="840" y="830" as="geometry" />
        </mxCell>
        <mxCell id="func-sched-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#006EAF;strokeWidth=2;fontSize=11;fontStyle=1;" value="Function App — Scheduler" vertex="1">
          <mxGeometry height="44" width="280" x="118" y="862" as="geometry" />
        </mxCell>
        <mxCell id="func-sched-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="Timer trigger  |  Nachtelijke batch (SAP sync)  |  Managed Identity" vertex="1">
          <mxGeometry height="16" width="280" x="118" y="906" as="geometry" />
        </mxCell>
        <mxCell id="func-sched-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/compute/Function_Apps.svg;" value="" vertex="1">
          <mxGeometry height="28" width="28" x="120" y="870" as="geometry" />
        </mxCell>
        <mxCell id="func-proc-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#006EAF;strokeWidth=2;fontSize=11;fontStyle=1;" value="Function App — Processor" vertex="1">
          <mxGeometry height="44" width="280" x="430" y="862" as="geometry" />
        </mxCell>
        <mxCell id="func-proc-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="Queue trigger  |  Service Bus  |  Managed Identity  |  Retry policy" vertex="1">
          <mxGeometry height="16" width="280" x="430" y="906" as="geometry" />
        </mxCell>
        <mxCell id="func-proc-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/compute/Function_Apps.svg;" value="" vertex="1">
          <mxGeometry height="28" width="28" x="432" y="870" as="geometry" />
        </mxCell>
        <mxCell id="func-rep-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#006EAF;strokeWidth=2;fontSize=11;fontStyle=1;" value="Function App — Reporter" vertex="1">
          <mxGeometry height="44" width="280" x="742" y="862" as="geometry" />
        </mxCell>
        <mxCell id="func-rep-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="HTTP trigger  |  Blob output  |  SMTP via ACS  |  Managed Identity" vertex="1">
          <mxGeometry height="16" width="280" x="742" y="906" as="geometry" />
        </mxCell>
        <mxCell id="func-rep-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/compute/Function_Apps.svg;" value="" vertex="1">
          <mxGeometry height="28" width="28" x="744" y="870" as="geometry" />
        </mxCell>
        <mxCell id="servicebus-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;strokeWidth=2;fontSize=11;fontStyle=1;" value="Service Bus (Premium)" vertex="1">
          <mxGeometry height="44" width="220" x="1060" y="862" as="geometry" />
        </mxCell>
        <mxCell id="servicebus-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="Queues + Topics  |  Private Endpoint  |  Geo-redundant" vertex="1">
          <mxGeometry height="16" width="220" x="1060" y="906" as="geometry" />
        </mxCell>
        <mxCell id="nsg-func" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;fontSize=9;" value="NSG: deny inbound internet, allow outbound naar Private Endpoints" vertex="1">
          <mxGeometry height="28" width="330" x="1310" y="862" as="geometry" />
        </mxCell>
        <mxCell id="udr-func" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;fontSize=9;" value="UDR: 0.0.0.0/0 → Azure Firewall" vertex="1">
          <mxGeometry height="28" width="330" x="1310" y="898" as="geometry" />
        </mxCell>
        <mxCell id="e-app-func" edge="1" parent="1" source="appservice-box" style="edgeStyle=orthogonalEdgeStyle;strokeColor=#9673a6;strokeWidth=1;dashed=1;" target="func-proc-box" value="API calls">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="sn-data-outer" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;strokeWidth=2;arcSize=3;" value="" vertex="1">
          <mxGeometry height="270" width="1560" x="100" y="1066" as="geometry" />
        </mxCell>
        <mxCell id="sn-data-label" parent="1" style="text;html=1;align=left;fontSize=10;fontStyle=1;fontColor=#2d6a1e;" value="snet-spoke-data  —  10.20.3.0/24  |  ✅ NSG  |  256 IPs (251 bruikbaar)  |  Uitsluitend Private Endpoints — geen publieke toegang" vertex="1">
          <mxGeometry height="18" width="900" x="118" y="1074" as="geometry" />
        </mxCell>
        <mxCell id="sqlmi-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#006EAF;strokeWidth=2;fontSize=12;fontStyle=1;" value="SQL Managed Instance" vertex="1">
          <mxGeometry height="46" width="300" x="118" y="1102" as="geometry" />
        </mxCell>
        <mxCell id="sqlmi-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="Business Critical  |  Always On HA  |  Automated backup (GRS)  |  Always Encrypted  |  500 GB  |  Private Endpoint" vertex="1">
          <mxGeometry height="28" width="300" x="118" y="1148" as="geometry" />
        </mxCell>
        <mxCell id="sqlmi-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/databases/SQL_Managed_Instance.svg;" value="" vertex="1">
          <mxGeometry height="32" width="32" x="120" y="1110" as="geometry" />
        </mxCell>
        <mxCell id="sqlmi-rep-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f0f8ff;strokeColor=#006EAF;strokeWidth=1;fontSize=11;dashed=1;" value="SQL MI — Geo-replica" vertex="1">
          <mxGeometry height="34" width="300" x="118" y="1186" as="geometry" />
        </mxCell>
        <mxCell id="sqlmi-rep-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="Auto-failover group  |  North Europe  |  RPO &lt; 5s" vertex="1">
          <mxGeometry height="16" width="300" x="118" y="1220" as="geometry" />
        </mxCell>
        <mxCell id="storage-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#006EAF;strokeWidth=2;fontSize=12;fontStyle=1;" value="Storage Account (Blob)" vertex="1">
          <mxGeometry height="46" width="300" x="460" y="1102" as="geometry" />
        </mxCell>
        <mxCell id="storage-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="GRS  |  Versioning  |  Soft-delete  |  Lifecycle management  |  Private Endpoint" vertex="1">
          <mxGeometry height="16" width="300" x="460" y="1148" as="geometry" />
        </mxCell>
        <mxCell id="storage-icon" parent="1" style="verticalLabelPosition=bottom;html=1;verticalAlign=top;align=center;strokeColor=none;fillColor=#00BEF2;shape=mxgraph.azure.storage_blob;pointerEvents=1;" value="" vertex="1">
          <mxGeometry height="30" width="30" x="462" y="1110" as="geometry" />
        </mxCell>
        <mxCell id="kv-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;strokeWidth=2;fontSize=12;fontStyle=1;" value="Azure Key Vault" vertex="1">
          <mxGeometry height="46" width="280" x="800" y="1102" as="geometry" />
        </mxCell>
        <mxCell id="kv-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="App secrets  |  DB connection strings  |  Certs  |  Managed HSM  |  Soft-delete  |  Private Endpoint" vertex="1">
          <mxGeometry height="16" width="280" x="800" y="1148" as="geometry" />
        </mxCell>
        <mxCell id="kv-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/security/Key_Vaults.svg;" value="" vertex="1">
          <mxGeometry height="34" width="34" x="802" y="1110" as="geometry" />
        </mxCell>
        <mxCell id="pe-sql-label" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f3e8ff;strokeColor=#9673a6;fontSize=9;" value="🔒 PE: sql-pe-001" vertex="1">
          <mxGeometry height="22" width="300" x="118" y="1240" as="geometry" />
        </mxCell>
        <mxCell id="pe-storage-label" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f3e8ff;strokeColor=#9673a6;fontSize=9;" value="🔒 PE: storage-pe-001" vertex="1">
          <mxGeometry height="22" width="300" x="460" y="1174" as="geometry" />
        </mxCell>
        <mxCell id="pe-kv-label" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f3e8ff;strokeColor=#9673a6;fontSize=9;" value="🔒 PE: kv-pe-001" vertex="1">
          <mxGeometry height="22" width="280" x="800" y="1174" as="geometry" />
        </mxCell>
        <mxCell id="pe-sb-label" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f3e8ff;strokeColor=#9673a6;fontSize=9;" value="🔒 PE: servicebus-pe-001" vertex="1">
          <mxGeometry height="46" width="280" x="1120" y="1102" as="geometry" />
        </mxCell>
        <mxCell id="nsg-data" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;fontSize=9;" value="NSG: deny all inbound except from func subnet (10.20.2.0/27) en web subnet (10.20.1.0/24)  |  Deny public endpoint access (Corp Policy)" vertex="1">
          <mxGeometry height="50" width="212" x="1430" y="1102" as="geometry" />
        </mxCell>
        <mxCell id="dns-zones-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;fontSize=10;fontStyle=1;" value="Private DNS Zones (via Hub DNS Resolver)" vertex="1">
          <mxGeometry height="28" width="522" x="1120" y="1196" as="geometry" />
        </mxCell>
        <mxCell id="dns-zones-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="privatelink.database.windows.net  |  privatelink.blob.core.windows.net  |  privatelink.vaultcore.azure.net  |  privatelink.servicebus.windows.net" vertex="1">
          <mxGeometry height="28" width="522" x="1120" y="1224" as="geometry" />
        </mxCell>
        <mxCell id="e-func-sql" edge="1" parent="1" source="func-sched-box" style="edgeStyle=orthogonalEdgeStyle;strokeColor=#006EAF;strokeWidth=1;dashed=1;" target="sqlmi-box" value="">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e-func-storage" edge="1" parent="1" source="func-rep-box" style="edgeStyle=orthogonalEdgeStyle;strokeColor=#006EAF;strokeWidth=1;dashed=1;" target="storage-box" value="">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e-app-kv" edge="1" parent="1" source="appservice-box" style="edgeStyle=orthogonalEdgeStyle;strokeColor=#9673a6;strokeWidth=1;dashed=1;fontSize=9;" target="kv-box" value="Managed Identity">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="sn-mgmt-outer" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;strokeWidth=2;arcSize=3;" value="" vertex="1">
          <mxGeometry height="140" width="1560" x="100" y="1356" as="geometry" />
        </mxCell>
        <mxCell id="sn-mgmt-label" parent="1" style="text;html=1;align=left;fontSize=10;fontStyle=1;fontColor=#2d6a1e;" value="snet-spoke-mgmt  —  10.20.4.0/27  |  ✅ NSG  |  32 IPs (27 bruikbaar)" vertex="1">
          <mxGeometry height="18" width="500" x="118" y="1364" as="geometry" />
        </mxCell>
        <mxCell id="devops-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#006EAF;strokeWidth=2;fontSize=11;fontStyle=1;" value="DevOps Self-Hosted Agents" vertex="1">
          <mxGeometry height="40" width="280" x="118" y="1390" as="geometry" />
        </mxCell>
        <mxCell id="devops-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="Azure DevOps  |  CI/CD pipelines  |  VNet-gebonden  |  Managed Identity" vertex="1">
          <mxGeometry height="16" width="280" x="118" y="1430" as="geometry" />
        </mxCell>
        <mxCell id="bastion-ref-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;strokeWidth=1;fontSize=11;fontStyle=1;dashed=1;" value="Azure Bastion (via Hub)" vertex="1">
          <mxGeometry height="40" width="280" x="430" y="1390" as="geometry" />
        </mxCell>
        <mxCell id="bastion-ref-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="Veilige RDP/SSH via browser  |  Geen public IP op VMs" vertex="1">
          <mxGeometry height="16" width="280" x="430" y="1430" as="geometry" />
        </mxCell>
        <mxCell id="nsg-mgmt" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;fontSize=9;" value="NSG: allow 3389/22 from AzureBastionSubnet, deny from internet  |  UDR: route via Hub Firewall" vertex="1">
          <mxGeometry height="28" width="880" x="750" y="1390" as="geometry" />
        </mxCell>
        <mxCell id="ext-outer" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;strokeWidth=2;arcSize=3;" value="" vertex="1">
          <mxGeometry height="800" width="600" x="1720" y="378" as="geometry" />
        </mxCell>
        <mxCell id="ext-title" parent="1" style="text;html=1;align=center;fontSize=13;fontStyle=1;fontColor=#444444;" value="Externe systemen &amp; Platformdiensten" vertex="1">
          <mxGeometry height="22" width="600" x="1720" y="386" as="geometry" />
        </mxCell>
        <mxCell id="sap-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;strokeWidth=2;fontSize=12;fontStyle=1;dashed=1;" value="SAP ERP" vertex="1">
          <mxGeometry height="46" width="220" x="1740" y="420" as="geometry" />
        </mxCell>
        <mxCell id="sap-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="On-premises  |  REST/SOAP  |  via S2S VPN  |  Nachtelijke batch" vertex="1">
          <mxGeometry height="16" width="220" x="1740" y="466" as="geometry" />
        </mxCell>
        <mxCell id="acs-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;strokeWidth=2;fontSize=11;fontStyle=1;" value="&amp;nbsp; &amp;nbsp; &amp;nbsp; &amp;nbsp; &amp;nbsp; Azure Communication Services" vertex="1">
          <mxGeometry height="46" width="220" x="1740" y="504" as="geometry" />
        </mxCell>
        <mxCell id="acs-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="Uitgaande mail (vervangt Exchange SMTP relay)  |  Private Link" vertex="1">
          <mxGeometry height="16" width="220" x="1740" y="550" as="geometry" />
        </mxCell>
        <mxCell id="law-ref-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#2d8a4e;strokeWidth=2;fontSize=11;fontStyle=1;" value="Log Analytics Workspace" vertex="1">
          <mxGeometry height="46" width="220" x="1740" y="588" as="geometry" />
        </mxCell>
        <mxCell id="law-ref-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="(Platform Mgmt Subscription)  |  App Insights  |  Diag logs  |  KQL queries" vertex="1">
          <mxGeometry height="16" width="220" x="1740" y="634" as="geometry" />
        </mxCell>
        <mxCell id="law-ref-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/analytics/Log_Analytics_Workspaces.svg;" value="" vertex="1">
          <mxGeometry height="28" width="28" x="1742" y="596" as="geometry" />
        </mxCell>
        <mxCell id="defender-ref-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;strokeWidth=2;fontSize=11;fontStyle=1;" value="Microsoft Defender for Cloud" vertex="1">
          <mxGeometry height="46" width="220" x="1740" y="672" as="geometry" />
        </mxCell>
        <mxCell id="defender-ref-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="(Platform Mgmt Subscription)  |  CSPM  |  Secure Score  |  Vulnerability assessment" vertex="1">
          <mxGeometry height="16" width="220" x="1740" y="718" as="geometry" />
        </mxCell>
        <mxCell id="fw-ref-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;strokeWidth=2;fontSize=11;fontStyle=1;" value="Azure Firewall Premium" vertex="1">
          <mxGeometry height="46" width="220" x="1740" y="756" as="geometry" />
        </mxCell>
        <mxCell id="fw-ref-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="(Hub — Connectivity Subscription)  |  IDPS  |  TLS-inspectie  |  UDR → all traffic" vertex="1">
          <mxGeometry height="16" width="220" x="1740" y="802" as="geometry" />
        </mxCell>
        <mxCell id="fw-ref-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/networking/Web_Application_Firewall_Policies_WAF.svg;" value="" vertex="1">
          <mxGeometry height="32" width="32" x="1742" y="762" as="geometry" />
        </mxCell>
        <mxCell id="entra-ref-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;strokeWidth=2;fontSize=11;fontStyle=1;" value="&amp;nbsp; &amp;nbsp; &amp;nbsp; &amp;nbsp; Entra ID + Conditional Access" vertex="1">
          <mxGeometry height="46" width="220" x="1740" y="840" as="geometry" />
        </mxCell>
        <mxCell id="entra-ref-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="(Platform Identity Subscription)  |  MFA  |  Managed Identities voor apps" vertex="1">
          <mxGeometry height="16" width="220" x="1740" y="886" as="geometry" />
        </mxCell>
        <mxCell id="entra-ref-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/identity/Tenant_Properties.svg;" value="" vertex="1">
          <mxGeometry height="28" width="36" x="1742" y="848" as="geometry" />
        </mxCell>
        <mxCell id="rsv-ref-box" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#2d8a4e;strokeWidth=2;fontSize=11;fontStyle=1;" value="Recovery Services Vault" vertex="1">
          <mxGeometry height="46" width="220" x="1740" y="924" as="geometry" />
        </mxCell>
        <mxCell id="rsv-ref-detail" parent="1" style="text;html=1;align=center;fontSize=9;fontColor=#666666;" value="(Platform Mgmt Subscription)  |  GRS  |  30d retentie  |  SQL MI + Blob backup" vertex="1">
          <mxGeometry height="16" width="220" x="1740" y="970" as="geometry" />
        </mxCell>
        <mxCell id="rsv-ref-icon" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/migrate/Recovery_Services_Vaults.svg;" value="" vertex="1">
          <mxGeometry height="28" width="32" x="1742" y="932" as="geometry" />
        </mxCell>
        <mxCell id="e-func-sap" edge="1" parent="1" source="func-sched-box" style="edgeStyle=orthogonalEdgeStyle;strokeColor=#b85450;strokeWidth=1;dashed=1;fontSize=9;fontColor=#b85450;" target="sap-box" value="REST/SOAP via ER">
          <mxGeometry relative="1" as="geometry">
            <Array as="points">
              <mxPoint x="258" y="950" />
              <mxPoint x="1660" y="950" />
              <mxPoint x="1660" y="443" />
            </Array>
          </mxGeometry>
        </mxCell>
        <mxCell id="e-func-acs" edge="1" parent="1" source="func-rep-box" style="edgeStyle=orthogonalEdgeStyle;strokeColor=#9673a6;strokeWidth=1;dashed=1;fontSize=9;" target="acs-box" value="SMTP">
          <mxGeometry relative="1" as="geometry">
            <Array as="points">
              <mxPoint x="1022" y="950" />
              <mxPoint x="1660" y="950" />
              <mxPoint x="1660" y="527" />
            </Array>
          </mxGeometry>
        </mxCell>
        <mxCell id="e-app-law" edge="1" parent="1" source="appservice-box" style="edgeStyle=orthogonalEdgeStyle;strokeColor=#2d8a4e;strokeWidth=1;dashed=1;fontSize=9;" target="law-ref-box" value="Diag logs">
          <mxGeometry relative="1" as="geometry">
            <Array as="points">
              <mxPoint x="628" y="700" />
              <mxPoint x="1660" y="700" />
              <mxPoint x="1660" y="611" />
            </Array>
          </mxGeometry>
        </mxCell>
        <mxCell id="legend-outer" parent="1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;" value="" vertex="1">
          <mxGeometry height="110" width="2260" x="60" y="1650" as="geometry" />
        </mxCell>
        <mxCell id="leg-title" parent="1" style="text;html=1;fontSize=12;fontStyle=1;align=left;" value="Legenda" vertex="1">
          <mxGeometry height="20" width="100" x="80" y="1658" as="geometry" />
        </mxCell>
        <mxCell id="leg1" parent="1" style="rounded=1;fillColor=#e8f4fd;strokeColor=#0050ef;strokeWidth=2;fontSize=10;fontStyle=1;" value="Subscription" vertex="1">
          <mxGeometry height="30" width="160" x="80" y="1686" as="geometry" />
        </mxCell>
        <mxCell id="leg2" parent="1" style="rounded=1;fillColor=#cce5ff;strokeColor=#0050ef;dashed=1;strokeWidth=2;fontSize=10;fontStyle=1;" value="Spoke VNet" vertex="1">
          <mxGeometry height="30" width="160" x="254" y="1686" as="geometry" />
        </mxCell>
        <mxCell id="leg3" parent="1" style="rounded=1;fillColor=#d5e8d4;strokeColor=#82b366;strokeWidth=2;fontSize=10;fontStyle=1;" value="Subnet" vertex="1">
          <mxGeometry height="30" width="120" x="428" y="1686" as="geometry" />
        </mxCell>
        <mxCell id="leg4" parent="1" style="rounded=1;fillColor=#dae8fc;strokeColor=#006EAF;strokeWidth=2;fontSize=10;fontStyle=1;" value="Azure PaaS service" vertex="1">
          <mxGeometry height="30" width="180" x="562" y="1686" as="geometry" />
        </mxCell>
        <mxCell id="leg5" parent="1" style="rounded=1;fillColor=#f8cecc;strokeColor=#b85450;strokeWidth=2;fontSize=10;fontStyle=1;" value="Security / WAF" vertex="1">
          <mxGeometry height="30" width="160" x="756" y="1686" as="geometry" />
        </mxCell>
        <mxCell id="leg6" parent="1" style="rounded=1;fillColor=#e1d5e7;strokeColor=#9673a6;strokeWidth=2;fontSize=10;fontStyle=1;" value="Identity / Key Vault" vertex="1">
          <mxGeometry height="30" width="160" x="930" y="1686" as="geometry" />
        </mxCell>
        <mxCell id="leg7" parent="1" style="rounded=1;fillColor=#ffe6cc;strokeColor=#d79b00;strokeWidth=2;fontSize=10;fontStyle=1;" value="NSG / UDR regel" vertex="1">
          <mxGeometry height="30" width="160" x="1104" y="1686" as="geometry" />
        </mxCell>
        <mxCell id="leg8" parent="1" style="rounded=1;fillColor=#fff2cc;strokeColor=#d6b656;dashed=1;fontSize=10;" value="Policy / DNS zones" vertex="1">
          <mxGeometry height="30" width="160" x="1278" y="1686" as="geometry" />
        </mxCell>
        <mxCell id="leg9" parent="1" style="rounded=1;fillColor=#f3e8ff;strokeColor=#9673a6;fontSize=10;" value="Private Endpoint" vertex="1">
          <mxGeometry height="30" width="160" x="1452" y="1686" as="geometry" />
        </mxCell>
        <mxCell id="leg10" parent="1" style="rounded=1;fillColor=#f8cecc;strokeColor=#b85450;dashed=1;strokeWidth=2;fontSize=10;fontStyle=1;" value="Extern / On-prem" vertex="1">
          <mxGeometry height="30" width="160" x="1626" y="1686" as="geometry" />
        </mxCell>
        <mxCell id="leg11" parent="1" style="rounded=1;fillColor=#f5f5f5;strokeColor=#666666;strokeWidth=2;fontSize=10;" value="Platform dienst (ref)" vertex="1">
          <mxGeometry height="30" width="180" x="1800" y="1686" as="geometry" />
        </mxCell>
        <mxCell id="leg12" parent="1" style="text;html=1;align=left;fontSize=9;fontColor=#666666;" value="🔒 = Private Endpoint (geen publieke toegang)  |  ✅ NSG = Network Security Group aanwezig  |  Managed Identity = geen credentials in code  |  UDR = User Defined Route via Hub Firewall" vertex="1">
          <mxGeometry height="18" width="1920" x="80" y="1724" as="geometry" />
        </mxCell>
        <mxCell id="IkEbLIkczLZkmBUhLSOW-1" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;fontSize=12;image=img/lib/azure2/networking/Bastions.svg;" value="" vertex="1">
          <mxGeometry height="34" width="29" x="453.5" y="1396" as="geometry" />
        </mxCell>
        <mxCell id="IkEbLIkczLZkmBUhLSOW-2" parent="1" style="image;sketch=0;aspect=fixed;html=1;points=[];align=center;fontSize=12;image=img/lib/mscae/Azure_DevOps.svg;" value="" vertex="1">
          <mxGeometry height="35" width="35" x="130" y="1392.5" as="geometry" />
        </mxCell>
        <mxCell id="IkEbLIkczLZkmBUhLSOW-3" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/databases/SQL_Managed_Instance.svg;" value="" vertex="1">
          <mxGeometry height="32" width="32" x="120" y="1188" as="geometry" />
        </mxCell>
        <mxCell id="IkEbLIkczLZkmBUhLSOW-4" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/networking/Subnet.svg;" value="" vertex="1">
          <mxGeometry height="23" width="34" x="840" y="1066" as="geometry" />
        </mxCell>
        <mxCell id="IkEbLIkczLZkmBUhLSOW-5" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;image=img/lib/azure2/networking/Subnet.svg;" value="" vertex="1">
          <mxGeometry height="23" width="34" x="840" y="1361.5" as="geometry" />
        </mxCell>
        <mxCell id="IkEbLIkczLZkmBUhLSOW-6" parent="1" style="image;aspect=fixed;html=1;points=[];align=center;fontSize=12;image=img/lib/azure2/other/Azure_Communication_Services.svg;" value="" vertex="1">
          <mxGeometry height="30" width="40.8" x="1742" y="512" as="geometry" />
        </mxCell>
        <mxCell id="IkEbLIkczLZkmBUhLSOW-8" parent="1" style="image;sketch=0;aspect=fixed;html=1;points=[];align=center;fontSize=12;image=img/lib/mscae/SAP_HANA_on_Azure.svg;" value="" vertex="1">
          <mxGeometry height="25" width="50" x="1742" y="431" as="geometry" />
        </mxCell>
        <mxCell id="IkEbLIkczLZkmBUhLSOW-9" parent="1" style="image;aspect=fixed;perimeter=ellipsePerimeter;html=1;align=center;shadow=0;dashed=0;spacingTop=3;image=img/lib/active_directory/internet_cloud.svg;" value="" vertex="1">
          <mxGeometry height="29.5" width="46.83" x="874" y="120" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>

[application-landing-zone-final.drawio](https://github.com/user-attachments/files/28393102/application-landing-zone-final.drawio)


De Contoso-applicatie wordt gemigreerd naar de volgende Azure PaaS-diensten:



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
