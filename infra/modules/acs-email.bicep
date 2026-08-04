param emailServiceName string
param emailDomainName string
param senderUsername string
param senderDisplayName string
param tags object

resource emailService 'Microsoft.Communication/emailServices@2023-04-01' = {
  name: emailServiceName
  location: 'global'
  tags: tags
  properties: {
    dataLocation: 'United States'
  }
}

resource emailDomain 'Microsoft.Communication/emailServices/domains@2023-04-01' = {
  parent: emailService
  name: emailDomainName
  location: 'global'
  tags: tags
  properties: {
    domainManagement: 'CustomerManaged'
    userEngagementTracking: 'Disabled'
  }
}

resource senderUsernameResource 'Microsoft.Communication/emailServices/domains/senderUsernames@2023-04-01' = {
  parent: emailDomain
  name: senderUsername
  properties: {
    username: senderUsername
    displayName: senderDisplayName
  }
}

output domainId string = emailDomain.id
