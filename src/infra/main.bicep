// Azure Synapse Analytics

param location string = resourceGroup().location
param synapseWorkspaceName string = 'nl-stu-jvw-synapse'
param sqlAdminLogin string = 'sqladmin'
param sqlAdminPassword string = 'P@ssw0rd1234!'
param defaultDataLakeStorageAccountName string = 'nlstujvwdatalake'
param defaultDataLakeStorageFilesystemName string = 'nl-stu-jvw-filesystem'
param logAnalyticsWorkspaceName string = 'nl-stu-jvw-logs'
param logAnalyticsWorkspaceSkuName string = 'PerGB2018'
param logAnalyticsWorkspaceRetentionInDays int = 30
param functionAppName string = 'nl-stu-jvw-func'
param appinsightsName string = 'nl-stu-jvw-applogs'
param functionstorageName string = 'nlstujvwfuncstore'


resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: defaultDataLakeStorageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    isHnsEnabled: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

resource funcstore 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: functionstorageName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    defaultToOAuthAuthentication: true
  }
}

resource dataLakeStorageContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  name: '${storageAccount.name}/default/${defaultDataLakeStorageFilesystemName}'
}

resource synapseWorkspace 'Microsoft.Synapse/workspaces@2021-06-01' = {
  name: synapseWorkspaceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    defaultDataLakeStorage: {
      accountUrl: 'https://${storageAccount.name}.dfs.core.windows.net'
      filesystem: defaultDataLakeStorageFilesystemName
    }
    sqlAdministratorLogin: sqlAdminLogin
    sqlAdministratorLoginPassword: sqlAdminPassword
  }
}

resource synapseFirewall 'Microsoft.Synapse/workspaces/firewallRules@2021-06-01' = {
  parent: synapseWorkspace
  name: 'allowAll'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

output synapseWorkspaceId string = synapseWorkspace.id
output storageAccountId string = storageAccount.id


resource azureFunction 'Microsoft.Web/sites@2024-04-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  tags: {
  }
  properties: {
    serverFarmId: asp.id
    siteConfig: {
      linuxFxVersion: 'Python|3.11'
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appinsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appinsights.properties.ConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${funcstore.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${funcstore.listKeys().keys[0].value}'
        }        
      ]
      cors: {
        allowedOrigins: [
          '*'
        ]
      }
    }
  }
}

resource asp 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${functionAppName}-plan'
  location: location
  kind: 'linux'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
  }
}

resource appinsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appinsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
  }
}


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: logAnalyticsWorkspaceSkuName
    }
    retentionInDays: logAnalyticsWorkspaceRetentionInDays
    features: {
      searchVersion: 1
    }
  }
}
