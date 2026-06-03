param location string
param tags object
param environmentName string
param logAnalyticsCustomerId string
@secure()
param logAnalyticsSharedKey string
param infrastructureSubnetId string
param identityId string
param acrLoginServer string
param storageAccountName string
@secure()
param storageAccountKey string
param appName string
param mailName string
param mysqlName string
param redisName string
param schedulerJobName string
param appUrl string
param anonaddyDomain string
param anonaddyHostname string
param anonaddyAdminUsername string
param anonaddyReturnPath string
param anonaddyAllDomains string
@secure()
param appKey string
@secure()
param anonaddySecret string
@secure()
param blocklistApiSecret string
param mysqlDatabase string
param mysqlUsername string
@secure()
param mysqlPassword string
@secure()
param mysqlRootPassword string
param mailFromName string
param mailFromAddress string
param mailAcsEndpoint string
@secure()
param mailAcsAccessKey string
param appCustomDomain string
param appMinReplicas int
param mailMinReplicas int
param mysqlMinReplicas int

var placeholderImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
var mysqlImage = 'mysql:8.4'
var redisImage = 'redis:7-alpine'
var commonSecrets = [
  {
    name: 'app-key'
    value: appKey
  }
  {
    name: 'anonaddy-secret'
    value: anonaddySecret
  }
  {
    name: 'blocklist-api-secret'
    value: blocklistApiSecret
  }
  {
    name: 'mysql-password'
    value: mysqlPassword
  }
  {
    name: 'mail-acs-access-key'
    value: mailAcsAccessKey
  }
]
var commonEnv = [
  {
    name: 'APP_NAME'
    value: 'AnonAddy'
  }
  {
    name: 'APP_ENV'
    value: 'production'
  }
  {
    name: 'APP_DEBUG'
    value: 'false'
  }
  {
    name: 'APP_URL'
    value: appUrl
  }
  {
    name: 'ASSET_URL'
    value: appUrl
  }
  {
    name: 'APP_KEY'
    secretRef: 'app-key'
  }
  {
    name: 'TRUSTED_PROXIES'
    value: '*'
  }
  {
    name: 'LOG_CHANNEL'
    value: 'stack'
  }
  {
    name: 'DB_CONNECTION'
    value: 'mysql'
  }
  {
    name: 'DB_HOST'
    value: mysqlName
  }
  {
    name: 'DB_PORT'
    value: '3306'
  }
  {
    name: 'DB_DATABASE'
    value: mysqlDatabase
  }
  {
    name: 'DB_USERNAME'
    value: mysqlUsername
  }
  {
    name: 'DB_PASSWORD'
    secretRef: 'mysql-password'
  }
  {
    name: 'CACHE_DRIVER'
    value: 'redis'
  }
  {
    name: 'QUEUE_CONNECTION'
    value: 'sync'
  }
  {
    name: 'SESSION_DRIVER'
    value: 'redis'
  }
  {
    name: 'REDIS_CLIENT'
    value: 'phpredis'
  }
  {
    name: 'REDIS_HOST'
    value: redisName
  }
  {
    name: 'REDIS_PASSWORD'
    value: 'null'
  }
  {
    name: 'REDIS_PORT'
    value: '6379'
  }
  {
    name: 'SESSION_SECURE_COOKIE'
    value: 'true'
  }
  {
    name: 'SAME_SITE_COOKIES'
    value: 'lax'
  }
  {
    name: 'ANONADDY_DOMAIN'
    value: anonaddyDomain
  }
  {
    name: 'ANONADDY_ALL_DOMAINS'
    value: anonaddyAllDomains
  }
  {
    name: 'ANONADDY_HOSTNAME'
    value: anonaddyHostname
  }
  {
    name: 'ANONADDY_ADMIN_USERNAME'
    value: anonaddyAdminUsername
  }
  {
    name: 'ANONADDY_RETURN_PATH'
    value: anonaddyReturnPath
  }
  {
    name: 'ANONADDY_ENABLE_REGISTRATION'
    value: 'true'
  }
  {
    name: 'ANONADDY_NON_ADMIN_USERNAME_SUBDOMAINS'
    value: 'true'
  }
  {
    name: 'ANONADDY_NON_ADMIN_SHARED_DOMAINS'
    value: 'true'
  }
  {
    name: 'ANONADDY_SECRET'
    secretRef: 'anonaddy-secret'
  }
  {
    name: 'BLOCKLIST_API_SECRET'
    secretRef: 'blocklist-api-secret'
  }
  {
    name: 'MAIL_MAILER'
    value: 'acs'
  }
  {
    name: 'MAIL_DRIVER'
    value: 'acs'
  }
  {
    name: 'MAIL_FROM_NAME'
    value: mailFromName
  }
  {
    name: 'MAIL_FROM_ADDRESS'
    value: mailFromAddress
  }
  {
    name: 'MAIL_ACS_ENDPOINT'
    value: mailAcsEndpoint
  }
  {
    name: 'MAIL_ACS_ACCESS_KEY'
    secretRef: 'mail-acs-access-key'
  }
  {
    name: 'MAIL_ACS_API_VERSION'
    value: '2023-03-31'
  }
]

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: environmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsCustomerId
        sharedKey: logAnalyticsSharedKey
      }
    }
    vnetConfiguration: {
      infrastructureSubnetId: infrastructureSubnetId
      internal: false
    }
  }
}

resource appStorage 'Microsoft.App/managedEnvironments/storages@2024-03-01' = {
  parent: environment
  name: 'app-storage'
  properties: {
    azureFile: {
      accountName: storageAccountName
      accountKey: storageAccountKey
      shareName: 'app-storage'
      accessMode: 'ReadWrite'
    }
  }
}

resource mysqlStorage 'Microsoft.App/managedEnvironments/storages@2024-03-01' = {
  parent: environment
  name: 'mysql-data'
  properties: {
    azureFile: {
      accountName: storageAccountName
      accountKey: storageAccountKey
      shareName: 'mysql-data'
      accessMode: 'ReadWrite'
    }
  }
}

resource mailCerts 'Microsoft.App/managedEnvironments/storages@2024-03-01' = {
  parent: environment
  name: 'mail-certs'
  properties: {
    azureFile: {
      accountName: storageAccountName
      accountKey: storageAccountKey
      shareName: 'mail-certs'
      accessMode: 'ReadWrite'
    }
  }
}

resource mailLogs 'Microsoft.App/managedEnvironments/storages@2024-03-01' = {
  parent: environment
  name: 'mail-logs'
  properties: {
    azureFile: {
      accountName: storageAccountName
      accountKey: storageAccountKey
      shareName: 'mail-logs'
      accessMode: 'ReadWrite'
    }
  }
}

resource mailSpool 'Microsoft.App/managedEnvironments/storages@2024-03-01' = {
  parent: environment
  name: 'mail-spool'
  properties: {
    azureFile: {
      accountName: storageAccountName
      accountKey: storageAccountKey
      shareName: 'mail-spool'
      accessMode: 'ReadWrite'
    }
  }
}

resource mysql 'Microsoft.App/containerApps@2024-03-01' = {
  name: mysqlName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 3306
        exposedPort: 3306
        transport: 'tcp'
      }
      secrets: [
        {
          name: 'mysql-password'
          value: mysqlPassword
        }
        {
          name: 'mysql-root-password'
          value: mysqlRootPassword
        }
      ]
    }
    template: {
      scale: {
        minReplicas: mysqlMinReplicas
        maxReplicas: 1
        rules: [
          {
            name: 'tcp'
            tcp: {
              metadata: {
                concurrentConnections: '10'
              }
            }
          }
        ]
      }
      containers: [
        {
          name: 'mysql'
          image: mysqlImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'MYSQL_DATABASE'
              value: mysqlDatabase
            }
            {
              name: 'MYSQL_USER'
              value: mysqlUsername
            }
            {
              name: 'MYSQL_PASSWORD'
              secretRef: 'mysql-password'
            }
            {
              name: 'MYSQL_ROOT_PASSWORD'
              secretRef: 'mysql-root-password'
            }
          ]
          volumeMounts: [
            {
              volumeName: 'mysql-data'
              mountPath: '/var/lib/mysql'
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'mysql-data'
          storageName: mysqlStorage.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
}

resource redis 'Microsoft.App/containerApps@2024-03-01' = {
  name: redisName
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 6379
        exposedPort: 6379
        transport: 'tcp'
      }
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 1
        rules: [
          {
            name: 'tcp'
            tcp: {
              metadata: {
                concurrentConnections: '10'
              }
            }
          }
        ]
      }
      containers: [
        {
          name: 'redis'
          image: redisImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
    }
  }
}

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [
        {
          server: acrLoginServer
          identity: identityId
        }
      ]
      ingress: {
        external: true
        targetPort: 80
        transport: 'http'
        allowInsecure: false
      }
      secrets: commonSecrets
    }
    template: {
      scale: {
        minReplicas: appMinReplicas
        maxReplicas: 1
      }
      containers: [
        {
          name: 'app'
          image: placeholderImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: concat(commonEnv, [
            {
              name: 'RUN_MIGRATIONS_ON_START'
              value: 'true'
            }
          ])
          volumeMounts: [
            {
              volumeName: 'app-storage'
              mountPath: '/var/www/html/storage'
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'app-storage'
          storageName: appStorage.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
  dependsOn: [
    mysql
    redis
  ]
}

resource mail 'Microsoft.App/containerApps@2024-03-01' = {
  name: mailName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [
        {
          server: acrLoginServer
          identity: identityId
        }
      ]
      secrets: commonSecrets
    }
    template: {
      scale: {
        minReplicas: mailMinReplicas
        maxReplicas: 1
        rules: [
          {
            name: 'smtp'
            tcp: {
              metadata: {
                concurrentConnections: '10'
              }
            }
          }
        ]
      }
      containers: [
        {
          name: 'mail'
          image: placeholderImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: concat(commonEnv, [
            {
              name: 'POSTFIX_MYNETWORKS'
              value: '10.42.0.0/16'
            }
            {
              name: 'POSTFIX_LOG_PATH'
              value: '/var/log/mail/mail.log'
            }
          ])
          volumeMounts: [
            {
              volumeName: 'app-storage'
              mountPath: '/var/www/html/storage'
            }
            {
              volumeName: 'mail-certs'
              mountPath: '/etc/postfix/certs'
            }
            {
              volumeName: 'mail-logs'
              mountPath: '/var/log/mail'
            }
            {
              volumeName: 'mail-spool'
              mountPath: '/var/spool/postfix'
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'app-storage'
          storageName: appStorage.name
          storageType: 'AzureFile'
        }
        {
          name: 'mail-certs'
          storageName: mailCerts.name
          storageType: 'AzureFile'
        }
        {
          name: 'mail-logs'
          storageName: mailLogs.name
          storageType: 'AzureFile'
        }
        {
          name: 'mail-spool'
          storageName: mailSpool.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
  dependsOn: [
    mysql
    redis
  ]
}

resource scheduler 'Microsoft.App/jobs@2024-03-01' = {
  name: schedulerJobName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identityId}': {}
    }
  }
  properties: {
    environmentId: environment.id
    configuration: {
      triggerType: 'Schedule'
      replicaTimeout: 600
      replicaRetryLimit: 1
      scheduleTriggerConfig: {
        cronExpression: '*/5 * * * *'
        parallelism: 1
        replicaCompletionCount: 1
      }
      registries: [
        {
          server: acrLoginServer
          identity: identityId
        }
      ]
      secrets: commonSecrets
    }
    template: {
      containers: [
        {
          name: 'scheduler'
          image: placeholderImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: commonEnv
          volumeMounts: [
            {
              volumeName: 'app-storage'
              mountPath: '/var/www/html/storage'
            }
            {
              volumeName: 'mail-logs'
              mountPath: '/var/log/mail'
            }
          ]
        }
      ]
      volumes: [
        {
          name: 'app-storage'
          storageName: appStorage.name
          storageType: 'AzureFile'
        }
        {
          name: 'mail-logs'
          storageName: mailLogs.name
          storageType: 'AzureFile'
        }
      ]
    }
  }
  dependsOn: [
    mysql
    redis
  ]
}

output appFqdn string = 'https://${app.properties.configuration.ingress.fqdn}'
output mailFqdn string = '${mailName}.${environment.properties.defaultDomain}'
output appCustomDomain string = appCustomDomain
output appDomainVerificationId string = app.properties.customDomainVerificationId
output environmentStaticIp string = environment.properties.staticIp
