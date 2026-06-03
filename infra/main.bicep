targetScope = 'subscription'

@description('azd environment name.')
param environmentName string

@description('Azure region for all resources.')
param location string

@description('Object ID of the deploying principal. Used for ACR push role assignment when supplied by azd.')
param principalId string = ''

@description('Public application URL, for example https://anon.bc3.tech.')
param appUrl string

@description('Primary AnonAddy alias domain.')
param anonaddyDomain string

@description('SMTP hostname used by Postfix.')
param anonaddyHostname string

@description('Admin username allowed to access admin features.')
param anonaddyAdminUsername string

@description('Return path used by AnonAddy.')
param anonaddyReturnPath string

@description('Comma-separated AnonAddy domains.')
param anonaddyAllDomains string

@secure()
@description('Laravel APP_KEY value.')
param appKey string

@secure()
@description('AnonAddy secret.')
param anonaddySecret string

@secure()
@description('Blocklist API secret.')
param blocklistApiSecret string

@description('MySQL database name.')
param mysqlDatabase string = 'anonaddy'

@description('MySQL application username.')
param mysqlUsername string = 'anonaddy'

@secure()
@description('MySQL application password.')
param mysqlPassword string

@secure()
@description('MySQL root password.')
param mysqlRootPassword string

@description('Outbound mail From display name.')
param mailFromName string = 'AnonAddy'

@description('Outbound mail From address.')
param mailFromAddress string

@description('Azure Communication Services Email endpoint.')
param mailAcsEndpoint string

@secure()
@description('Azure Communication Services Email access key.')
param mailAcsAccessKey string

@description('Minimum replicas for the web app. Keep 0 for cheapest scale-to-zero.')
param appMinReplicas int = 0

@description('Minimum replicas for inbound SMTP. Keep 0 for cheapest; use 1 for more reliable SMTP acceptance.')
param mailMinReplicas int = 0

@description('Minimum replicas for MySQL. Keep 0 for cheapest; use 1 if DB cold starts cause connection failures.')
param mysqlMinReplicas int = 0

var abbrs = json(loadTextContent('./abbreviations.json'))
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = {
  'azd-env-name': environmentName
  workload: 'anonaddy'
}
var resourceGroupName = 'rg-${environmentName}-${resourceToken}'
var acrName = '${abbrs.containerRegistryRegistries}${replace(resourceToken, '-', '')}'
var storageName = '${abbrs.storageStorageAccounts}${replace(resourceToken, '-', '')}'
var environmentNameActual = '${abbrs.appManagedEnvironments}${environmentName}-${resourceToken}'
var appName = '${abbrs.appContainerApps}app-${environmentName}-${resourceToken}'
var mailName = '${abbrs.appContainerApps}mail-${environmentName}-${resourceToken}'
var mysqlName = '${abbrs.appContainerApps}mysql-${environmentName}-${resourceToken}'
var identityName = '${abbrs.managedIdentityUserAssignedIdentities}${environmentName}-${resourceToken}'
var logName = '${abbrs.operationalInsightsWorkspaces}${environmentName}-${resourceToken}'
var vnetName = '${abbrs.networkVirtualNetworks}${environmentName}-${resourceToken}'
var acaSubnetName = '${abbrs.networkVirtualNetworksSubnets}aca-${environmentName}-${resourceToken}'

resource rg 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module core './modules/core.bicep' = {
  name: 'core'
  scope: rg
  params: {
    location: location
    tags: tags
    acrName: acrName
    storageName: storageName
    logAnalyticsName: logName
    identityName: identityName
    principalId: principalId
  }
}

module network './modules/network.bicep' = {
  name: 'network'
  scope: rg
  params: {
    location: location
    tags: tags
    vnetName: vnetName
    acaSubnetName: acaSubnetName
  }
}

module apps './modules/container-apps.bicep' = {
  name: 'containerApps'
  scope: rg
  params: {
    location: location
    tags: tags
    environmentName: environmentNameActual
    logAnalyticsCustomerId: core.outputs.logAnalyticsCustomerId
    logAnalyticsSharedKey: core.outputs.logAnalyticsSharedKey
    infrastructureSubnetId: network.outputs.acaSubnetId
    identityId: core.outputs.identityId
    acrLoginServer: core.outputs.acrLoginServer
    storageAccountName: core.outputs.storageAccountName
    storageAccountKey: core.outputs.storageAccountKey
    appName: appName
    mailName: mailName
    mysqlName: mysqlName
    appUrl: appUrl
    anonaddyDomain: anonaddyDomain
    anonaddyHostname: anonaddyHostname
    anonaddyAdminUsername: anonaddyAdminUsername
    anonaddyReturnPath: anonaddyReturnPath
    anonaddyAllDomains: anonaddyAllDomains
    appKey: appKey
    anonaddySecret: anonaddySecret
    blocklistApiSecret: blocklistApiSecret
    mysqlDatabase: mysqlDatabase
    mysqlUsername: mysqlUsername
    mysqlPassword: mysqlPassword
    mysqlRootPassword: mysqlRootPassword
    mailFromName: mailFromName
    mailFromAddress: mailFromAddress
    mailAcsEndpoint: mailAcsEndpoint
    mailAcsAccessKey: mailAcsAccessKey
    appMinReplicas: appMinReplicas
    mailMinReplicas: mailMinReplicas
    mysqlMinReplicas: mysqlMinReplicas
  }
}

output RESOURCE_GROUP_NAME string = rg.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = core.outputs.acrLoginServer
output APP_CONTAINER_APP_NAME string = appName
output MAIL_CONTAINER_APP_NAME string = mailName
output MYSQL_CONTAINER_APP_NAME string = mysqlName
output CONTAINER_APP_ENVIRONMENT_NAME string = environmentNameActual
output APP_URL string = apps.outputs.appFqdn
output SMTP_HOSTNAME string = apps.outputs.mailFqdn
