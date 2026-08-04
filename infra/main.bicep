targetScope = 'subscription'

extension 'br:mcr.microsoft.com/bicep/extensions/microsoftgraph/v1.0:1.0.0'

@description('azd environment name.')
param environmentName string

@description('Azure region for all resources.')
param location string

@description('Object ID of the deploying principal. Used for ACR push role assignment when supplied by azd.')
param principalId string = ''

@description('Public application URL, for example https://anon.bc3.tech.')
param appUrl string

@description('Custom HTTPS hostname for the app Container App.')
param appCustomDomain string = 'anon.bc3.tech'

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

@description('Azure Communication Services Email endpoint.')
@minLength(1)
param mailAcsEndpoint string

@secure()
@description('Azure Communication Services Email access key.')
@minLength(1)
param mailAcsAccessKey string

@description('Domain verified with Azure Communication Services Email.')
param mailAcsEmailDomainName string

@description('Local part of the ACS sender address.')
param mailAcsSenderUsername string = 'reply-to-sender'

@description('Container image for the app service. azd sets SERVICE_APP_IMAGE_NAME after deploy.')
param appImageName string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Container image for the mail service. azd sets SERVICE_MAIL_IMAGE_NAME after deploy.')
param mailImageName string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Minimum replicas for the web app. Keep 0 for cheapest scale-to-zero.')
param appMinReplicas int = 0

@description('Minimum replicas for inbound SMTP. Must be >= 1 for SMTP acceptance to function properly.')
param mailMinReplicas int = 1

@description('Minimum replicas for MySQL. Keep 1 to avoid DB cold-start connection failures during user requests.')
param mysqlMinReplicas int = 1

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
var redisName = '${abbrs.appContainerApps}redis-${environmentName}-${resourceToken}'
var schedulerJobName = 'job-sch-${resourceToken}'
var migrateJobName = 'job-mig-${resourceToken}'
var identityName = '${abbrs.managedIdentityUserAssignedIdentities}${environmentName}-${resourceToken}'
var logName = '${abbrs.operationalInsightsWorkspaces}${environmentName}-${resourceToken}'
var vnetName = '${abbrs.networkVirtualNetworks}${environmentName}-${resourceToken}'
var acaSubnetName = '${abbrs.networkVirtualNetworksSubnets}aca-${environmentName}-${resourceToken}'
var mailAcsEmailServiceName = 'email-${environmentName}-${resourceToken}'
var mailFromAddress = '${mailAcsSenderUsername}@${mailAcsEmailDomainName}'

resource mailApplication 'Microsoft.Graph/applications@v1.0' = {
  uniqueName: 'anonaddy-mail-${resourceToken}'
  displayName: 'anonaddy-mail-${environmentName}'
  signInAudience: 'AzureADMyOrg'
}

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

module acsEmail './modules/acs-email.bicep' = {
  name: 'acsEmail'
  scope: rg
  params: {
    emailServiceName: mailAcsEmailServiceName
    emailDomainName: mailAcsEmailDomainName
    senderUsername: mailAcsSenderUsername
    senderDisplayName: mailFromName
    tags: tags
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
    redisName: redisName
    schedulerJobName: schedulerJobName
    migrateJobName: migrateJobName
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
    appImageName: appImageName
    mailImageName: mailImageName
    appCustomDomain: appCustomDomain
    appMinReplicas: appMinReplicas
    mailMinReplicas: mailMinReplicas
    mysqlMinReplicas: mysqlMinReplicas
  }
}

output APP_CONTAINER_APP_NAME string = appName
output APP_CUSTOM_DOMAIN string = appCustomDomain
output APP_DOMAIN_VERIFICATION_ID string = apps.outputs.appDomainVerificationId
output APP_INGRESS_URL string = apps.outputs.appFqdn
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = core.outputs.acrLoginServer
output CONTAINER_APP_ENVIRONMENT_NAME string = environmentNameActual
output CONTAINER_APP_ENVIRONMENT_STATIC_IP string = apps.outputs.environmentStaticIp
output MAIL_ACS_EMAIL_SERVICE_NAME string = mailAcsEmailServiceName
output MAIL_CONTAINER_APP_NAME string = mailName
output MAIL_ENTRA_APPLICATION_CLIENT_ID string = mailApplication.appId
output MIGRATE_CONTAINER_APP_JOB_NAME string = migrateJobName
output MYSQL_CONTAINER_APP_NAME string = mysqlName
output REDIS_CONTAINER_APP_NAME string = redisName
output RESOURCE_GROUP_NAME string = rg.name
output SCHEDULER_CONTAINER_APP_JOB_NAME string = schedulerJobName
output SMTP_CUSTOM_HOSTNAME string = anonaddyHostname
output SMTP_HOSTNAME string = apps.outputs.mailFqdn
output WILDCARD_MX_DOMAIN string = '*.${anonaddyDomain}'
