param location string
param tags object
param acrName string
param storageName string
param logAnalyticsName string
param identityName string
param principalId string = ''

var acrPushRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '8311e382-0749-4cb8-b61a-304f252e45ec')
var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: identityName
  location: location
  tags: tags
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: logAnalyticsName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: json('0.1')
    }
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2025-01-01' = {
  name: storageName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource appShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-01-01' = {
  name: '${storage.name}/default/app-storage'
  properties: {
    shareQuota: 5
  }
}

resource mysqlShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-01-01' = {
  name: '${storage.name}/default/mysql-data'
  properties: {
    shareQuota: 10
  }
}

resource mailCertsShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-01-01' = {
  name: '${storage.name}/default/mail-certs'
  properties: {
    shareQuota: 1
  }
}

resource mailLogsShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-01-01' = {
  name: '${storage.name}/default/mail-logs'
  properties: {
    shareQuota: 2
  }
}

resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, identity.id, acrPullRoleDefinitionId)
  scope: acr
  properties: {
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: acrPullRoleDefinitionId
  }
}

resource acrPush 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(principalId)) {
  name: guid(acr.id, principalId, acrPushRoleDefinitionId)
  scope: acr
  properties: {
    principalId: principalId
    roleDefinitionId: acrPushRoleDefinitionId
  }
}

output identityId string = identity.id
output identityClientId string = identity.properties.clientId
output acrLoginServer string = acr.properties.loginServer
output storageAccountName string = storage.name
@secure()
output storageAccountKey string = storage.listKeys().keys[0].value
output logAnalyticsCustomerId string = logAnalytics.properties.customerId
@secure()
output logAnalyticsSharedKey string = logAnalytics.listKeys().primarySharedKey
