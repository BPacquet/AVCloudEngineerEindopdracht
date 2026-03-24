# 06 — ci/cd pipelines

> **Deliverable**: Azure DevOps YAML pipelines voor IaC en applicatie-deployment  
> **Gewicht**: 10% van de totale eindopdrachtscore

---

## opdracht

Schrijf **twee CI/CD YAML-pipelines** voor de Contoso-omgeving:

1. **IaC pipeline** (`iac-pipeline.yml`) — Deploy Bicep-templates naar Azure
2. **App pipeline** (`app-pipeline.yml`) — Build, test en deploy de .NET-applicatie naar App Service

---

## pipeline overzicht

### omgevingen

| Omgeving | Branch | Auto-deploy? | Approval? |
|---|---|---|---|
| `dev` | `feature/*`, `develop` | ✅ Ja | ❌ Nee |
| `tst` | `develop`, `release/*` | ✅ Ja | ❌ Nee |
| `prd` | `main` | ❌ Nee | ✅ Ja (2 approvers) |

### service connections

Documenteer welke Service Connections je nodig hebt in Azure DevOps:

| Naam | Type | Scope | Gebruik |
|---|---|---|---|
| `sc-azure-dev` | Azure Resource Manager (Workload Identity) | Dev Subscription | IaC deploy dev |
| `sc-azure-tst` | Azure Resource Manager (Workload Identity) | Tst Subscription | IaC deploy tst |
| `sc-azure-prd` | Azure Resource Manager (Workload Identity) | Prd Subscription | IaC deploy prd |
| `sc-acr` | Docker Registry (Azure Container Registry) | — | (optioneel, indien containers) |

> 💡 Gebruik **Workload Identity Federation** (OIDC) voor service connections — geen geheimen opslaan!

---

## iac-pipeline.yml — starter

```yaml
# iac-pipeline.yml
# Deploys Bicep infrastructure to Azure
# Triggered on changes to 05-bicep/**

name: 'IaC Deploy — $(Date:yyyyMMdd)$(Rev:.r)'

trigger:
  branches:
    include:
      - main
      - develop
  paths:
    include:
      - '05-bicep/**'

pr:
  branches:
    include:
      - main
      - develop
  paths:
    include:
      - '05-bicep/**'

# ──────────────────────────────────────────────
# Variables
# ──────────────────────────────────────────────

variables:
  bicepDirectory: '$(Build.SourcesDirectory)/05-bicep'
  azureLocation: 'westeurope'

# ──────────────────────────────────────────────
# Stages
# ──────────────────────────────────────────────

stages:

  # ────────── VALIDATE ──────────────────────────
  - stage: Validate
    displayName: '🔍 Validate Bicep'
    jobs:
      - job: Lint
        displayName: 'Bicep Lint & Build'
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - checkout: self

          - task: AzureCLI@2
            displayName: 'Install Bicep CLI'
            inputs:
              azureSubscription: 'sc-azure-dev'
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                az bicep upgrade
                az bicep version

          - task: AzureCLI@2
            displayName: 'Bicep Lint'
            inputs:
              azureSubscription: 'sc-azure-dev'
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                az bicep lint --file $(bicepDirectory)/main.bicep

          - task: AzureCLI@2
            displayName: 'Bicep Build (compile to ARM)'
            inputs:
              azureSubscription: 'sc-azure-dev'
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                az bicep build --file $(bicepDirectory)/main.bicep \
                  --outdir $(Build.ArtifactStagingDirectory)

          - publish: '$(Build.ArtifactStagingDirectory)'
            artifact: 'bicep-arm'
            displayName: 'Publish ARM artifact'

      - job: WhatIf_Dev
        displayName: 'What-If: DEV'
        dependsOn: Lint
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - checkout: self

          - task: AzureCLI@2
            displayName: 'az deployment sub what-if (dev)'
            inputs:
              azureSubscription: 'sc-azure-dev'
              scriptType: bash
              scriptLocation: inlineScript
              inlineScript: |
                az deployment sub what-if \
                  --location $(azureLocation) \
                  --template-file $(bicepDirectory)/main.bicep \
                  --parameters $(bicepDirectory)/main.dev.bicepparam \
                  --result-format FullResourcePayloads

  # ────────── DEPLOY DEV ────────────────────────
  - stage: Deploy_Dev
    displayName: '🚀 Deploy — DEV'
    dependsOn: Validate
    condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
    variables:
      environment: 'dev'
    jobs:
      - deployment: DeployInfra_Dev
        displayName: 'Deploy Infrastructure to DEV'
        pool:
          vmImage: 'ubuntu-latest'
        environment: 'dev'              # Azure DevOps Environment (geen approval)
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self

                - task: AzureCLI@2
                  displayName: 'Deploy Bicep to DEV'
                  inputs:
                    azureSubscription: 'sc-azure-dev'
                    scriptType: bash
                    scriptLocation: inlineScript
                    inlineScript: |
                      az deployment sub create \
                        --name "iac-$(Build.BuildNumber)" \
                        --location $(azureLocation) \
                        --template-file $(bicepDirectory)/main.bicep \
                        --parameters $(bicepDirectory)/main.dev.bicepparam \
                        --parameters environment='dev'

  # ────────── DEPLOY TST ────────────────────────
  - stage: Deploy_Tst
    displayName: '🧪 Deploy — TST'
    dependsOn: Deploy_Dev
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/develop'))
    variables:
      environment: 'tst'
    jobs:
      - deployment: DeployInfra_Tst
        displayName: 'Deploy Infrastructure to TST'
        pool:
          vmImage: 'ubuntu-latest'
        environment: 'tst'
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self

                - task: AzureCLI@2
                  displayName: 'Deploy Bicep to TST'
                  inputs:
                    azureSubscription: 'sc-azure-tst'
                    scriptType: bash
                    scriptLocation: inlineScript
                    inlineScript: |
                      az deployment sub create \
                        --name "iac-$(Build.BuildNumber)" \
                        --location $(azureLocation) \
                        --template-file $(bicepDirectory)/main.bicep \
                        --parameters environment='tst'

  # ────────── DEPLOY PRD ────────────────────────
  - stage: Deploy_Prd
    displayName: '🏭 Deploy — PRD'
    dependsOn: Deploy_Tst
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    variables:
      environment: 'prd'
    jobs:
      - deployment: DeployInfra_Prd
        displayName: 'Deploy Infrastructure to PRD'
        pool:
          vmImage: 'ubuntu-latest'
        environment: 'prd'             # Azure DevOps Environment MET approval gate!
        strategy:
          runOnce:
            deploy:
              steps:
                - checkout: self

                - task: AzureCLI@2
                  displayName: 'Deploy Bicep to PRD'
                  inputs:
                    azureSubscription: 'sc-azure-prd'
                    scriptType: bash
                    scriptLocation: inlineScript
                    inlineScript: |
                      az deployment sub create \
                        --name "iac-$(Build.BuildNumber)" \
                        --location $(azureLocation) \
                        --template-file $(bicepDirectory)/main.bicep \
                        --parameters $(bicepDirectory)/main.bicepparam \
                        --parameters environment='prd'
```

---

## app-pipeline.yml — starter

```yaml
# app-pipeline.yml
# Build, test en deploy .NET applicatie naar Azure App Service
# Triggered op changes aan de applicatiecode

name: 'App Deploy — $(Date:yyyyMMdd)$(Rev:.r)'

trigger:
  branches:
    include:
      - main
      - develop
      - 'feature/*'
  paths:
    exclude:
      - '05-bicep/**'
      - '*.md'

pr:
  branches:
    include:
      - main
      - develop

# ──────────────────────────────────────────────
# Variables
# ──────────────────────────────────────────────

variables:
  dotnetVersion: '8.x'
  buildConfiguration: 'Release'
  projectPath: 'src/Contoso.Web/Contoso.Web.csproj'
  testProjectPath: 'src/Contoso.Tests/Contoso.Tests.csproj'

# ──────────────────────────────────────────────
# Stages
# ──────────────────────────────────────────────

stages:

  # ────────── BUILD & TEST ──────────────────────
  - stage: Build
    displayName: '🏗️ Build & Test'
    jobs:
      - job: BuildAndTest
        displayName: 'Build, Unit Test & Publish'
        pool:
          vmImage: 'windows-latest'       # Windows voor ASP.NET WebForms
        steps:
          - checkout: self

          - task: UseDotNet@2
            displayName: 'Install .NET $(dotnetVersion)'
            inputs:
              packageType: 'sdk'
              version: $(dotnetVersion)

          - task: DotNetCoreCLI@2
            displayName: 'dotnet restore'
            inputs:
              command: 'restore'
              projects: '**/*.csproj'

          - task: DotNetCoreCLI@2
            displayName: 'dotnet build'
            inputs:
              command: 'build'
              projects: $(projectPath)
              arguments: '--configuration $(buildConfiguration) --no-restore'

          - task: DotNetCoreCLI@2
            displayName: 'dotnet test (unit tests)'
            inputs:
              command: 'test'
              projects: $(testProjectPath)
              arguments: >
                --configuration $(buildConfiguration)
                --no-build
                --collect:"XPlat Code Coverage"
                --results-directory $(Agent.TempDirectory)/TestResults
              publishTestResults: true

          - task: PublishCodeCoverageResults@2
            displayName: 'Publish code coverage'
            inputs:
              summaryFileLocation: '$(Agent.TempDirectory)/TestResults/**/*.xml'

          - task: DotNetCoreCLI@2
            displayName: 'dotnet publish'
            inputs:
              command: 'publish'
              publishWebProjects: true
              arguments: >
                --configuration $(buildConfiguration)
                --output $(Build.ArtifactStagingDirectory)/app

          - publish: '$(Build.ArtifactStagingDirectory)/app'
            artifact: 'app-package'
            displayName: 'Publish app artifact'

  # ────────── SECURITY SCAN ─────────────────────
  - stage: SecurityScan
    displayName: '🔐 Security Scan'
    dependsOn: Build
    jobs:
      - job: SAST
        displayName: 'Static Application Security Testing'
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          # TODO: Voeg SAST tool toe (bijv. SonarCloud, Checkmarx, of GitHub Advanced Security)
          - script: echo "SAST scan placeholder — implementeer SonarCloud of vergelijkbaar"
            displayName: 'SAST Scan'

          # Dependency vulnerability scan
          - task: DotNetCoreCLI@2
            displayName: 'dotnet list vulnerable packages'
            inputs:
              command: 'custom'
              custom: 'list'
              arguments: 'package --vulnerable --include-transitive'

  # ────────── DEPLOY DEV ────────────────────────
  - stage: Deploy_Dev
    displayName: '🚀 Deploy — DEV'
    dependsOn:
      - Build
      - SecurityScan
    condition: and(succeeded(), ne(variables['Build.Reason'], 'PullRequest'))
    jobs:
      - deployment: DeployApp_Dev
        displayName: 'Deploy App to DEV'
        pool:
          vmImage: 'ubuntu-latest'
        environment: 'dev'
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: 'app-package'

                - task: AzureWebApp@1
                  displayName: 'Deploy to App Service DEV'
                  inputs:
                    azureSubscription: 'sc-azure-dev'
                    appType: 'webApp'
                    appName: 'app-contoso-dev-web'
                    package: '$(Pipeline.Workspace)/app-package/**/*.zip'
                    deploymentMethod: 'zipDeploy'

  # ────────── DEPLOY TST ────────────────────────
  - stage: Deploy_Tst
    displayName: '🧪 Deploy — TST'
    dependsOn: Deploy_Dev
    condition: >
      and(
        succeeded(),
        in(variables['Build.SourceBranch'], 'refs/heads/develop', 'refs/heads/main')
      )
    jobs:
      - deployment: DeployApp_Tst
        displayName: 'Deploy App to TST'
        pool:
          vmImage: 'ubuntu-latest'
        environment: 'tst'
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: 'app-package'

                - task: AzureWebApp@1
                  displayName: 'Deploy to App Service TST (staging slot)'
                  inputs:
                    azureSubscription: 'sc-azure-tst'
                    appType: 'webApp'
                    appName: 'app-contoso-tst-web'
                    deployToSlotOrASE: true
                    resourceGroupName: 'rg-contoso-tst-frontend'
                    slotName: 'staging'
                    package: '$(Pipeline.Workspace)/app-package/**/*.zip'

                # TODO: Voeg integratietests toe na staging deployment

                - task: AzureAppServiceManage@0
                  displayName: 'Swap staging → production (TST)'
                  inputs:
                    azureSubscription: 'sc-azure-tst'
                    Action: 'Swap Slots'
                    WebAppName: 'app-contoso-tst-web'
                    ResourceGroupName: 'rg-contoso-tst-frontend'
                    SourceSlot: 'staging'

  # ────────── DEPLOY PRD ────────────────────────
  - stage: Deploy_Prd
    displayName: '🏭 Deploy — PRD'
    dependsOn: Deploy_Tst
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployApp_Prd
        displayName: 'Deploy App to PRD'
        pool:
          vmImage: 'ubuntu-latest'
        environment: 'prd'             # Approval gate geconfigureerd in Azure DevOps!
        strategy:
          runOnce:
            deploy:
              steps:
                - download: current
                  artifact: 'app-package'

                - task: AzureWebApp@1
                  displayName: 'Deploy to App Service PRD (staging slot)'
                  inputs:
                    azureSubscription: 'sc-azure-prd'
                    appType: 'webApp'
                    appName: 'app-contoso-prd-web'
                    deployToSlotOrASE: true
                    resourceGroupName: 'rg-contoso-prd-frontend'
                    slotName: 'staging'
                    package: '$(Pipeline.Workspace)/app-package/**/*.zip'

                # Health check op staging slot vóór swap
                - script: |
                    echo "Running smoke tests on staging slot..."
                    statusCode=$(curl -s -o /dev/null -w "%{http_code}" \
                      https://app-contoso-prd-web-staging.azurewebsites.net/health)
                    if [ "$statusCode" != "200" ]; then
                      echo "Health check failed! Status: $statusCode"
                      exit 1
                    fi
                    echo "Health check passed!"
                  displayName: 'Health check staging slot'

                - task: AzureAppServiceManage@0
                  displayName: '🔄 Swap staging → production (PRD)'
                  inputs:
                    azureSubscription: 'sc-azure-prd'
                    Action: 'Swap Slots'
                    WebAppName: 'app-contoso-prd-web'
                    ResourceGroupName: 'rg-contoso-prd-frontend'
                    SourceSlot: 'staging'
```

---

## opdrachttaken

Vul de starter pipelines aan en documenteer je keuzes:

| Taak | Beschrijving | Status |
|---|---|---|
| `iac-pipeline.yml` | IaC pipeline starter aanwezig | ✅ Gegeven |
| `app-pipeline.yml` | App pipeline starter aanwezig | ✅ Gegeven |
| SAST scan | Voeg een echte SAST-tool toe (SonarCloud/Checkmarx) | ❌ Jij |
| Integratietests | Voeg integratietests toe na TST-deployment | ❌ Jij |
| Rollback mechanisme | Documenteer hoe je terugdraait bij falen in PRD | ❌ Jij |
| Variable groups | Vervang hardcoded namen door Azure DevOps variable groups | ❌ Jij |
| Approvers configuratie | Documenteer wie de PRD approval gates beheert | ❌ Jij |

---

## approval gate configuratie

Documenteer hoe je de **approval gate voor productie** instelt in Azure DevOps:

1. Ga in Azure DevOps naar **Pipelines → Environments → prd**
2. Klik op "Approvals and checks"
3. Voeg een "Approvals" check toe met:
   - Minimaal **2 approvers** (bijv. Tech Lead + Product Owner)
   - Timeout: **24 uur**
   - Instructies voor approver: "Controleer de TST-omgeving voor akkoord"
4. Voeg optioneel een "Business hours" check toe (deployments enkel tijdens kantooruren)

---

## rollback strategie

Documenteer je rollback-strategie voor beide pipelines:

### IaC rollback

| Scenario | Actie |
|---|---|
| Bicep deployment mislukt | `az deployment sub cancel` → corrigeer template → herdeployeer |
| Resource in fout staat | `az resource delete` indien idempotent, of handmatige correctie |
| Volledige rollback vereist | Gebruik Git revert → trigger pipeline opnieuw |

### Applicatie rollback

| Scenario | Actie |
|---|---|
| Health check mislukt op staging | Slot swap wordt NIET uitgevoerd — production onaangetast |
| Probleem ontdekt na swap | Swap staging ↔ production terug (vorige versie zit nog in staging slot) |
| Critieke bug in productie | Voer `AzureAppServiceManage` swap terug uit via pipeline of manueel |

---

## wat je inlevert

```
06-cicd/
├── README.md          ← dit bestand, volledig ingevuld + opdrachttaken afgewerkt
├── iac-pipeline.yml   ← volledig uitgewerkte IaC pipeline
└── app-pipeline.yml   ← volledig uitgewerkte app pipeline
```

---

## beoordelingscriteria (10 punten)

| Criterium | Punten |
|---|---|
| IaC pipeline: validate → deploy per omgeving | 3 |
| App pipeline: build → test → deploy per omgeving | 3 |
| Approval gate voor productie aanwezig + gedocumenteerd | 2 |
| Rollback strategie gedocumenteerd | 1 |
| Security scan stap aanwezig (SAST/dependency) | 1 |

---

_Terug naar [`../README.md`](../README.md) voor het overzicht_

---

_delaware cloud practice — we commit. we deliver._
