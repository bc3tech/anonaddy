using './main.bicep'

param environmentName = readEnvironmentVariable('AZURE_ENV_NAME', 'dev')
param location = readEnvironmentVariable('AZURE_LOCATION', 'westus2')
param principalId = readEnvironmentVariable('AZURE_PRINCIPAL_ID', '')

param appUrl = readEnvironmentVariable('APP_URL', 'https://anon.bc3.tech')
param appCustomDomain = readEnvironmentVariable('APP_CUSTOM_DOMAIN', 'anon.bc3.tech')
param anonaddyDomain = readEnvironmentVariable('ANONADDY_DOMAIN', 'anon.bc3.tech')
param anonaddyHostname = readEnvironmentVariable('ANONADDY_HOSTNAME', 'mail.anon.bc3.tech')
param anonaddyAdminUsername = readEnvironmentVariable('ANONADDY_ADMIN_USERNAME', 'admin')
param anonaddyReturnPath = readEnvironmentVariable('ANONADDY_RETURN_PATH', 'mailer@anon.bc3.tech')
param anonaddyAllDomains = readEnvironmentVariable('ANONADDY_ALL_DOMAINS', 'anon.bc3.tech')

param appKey = readEnvironmentVariable('APP_KEY', '')
param anonaddySecret = readEnvironmentVariable('ANONADDY_SECRET', '')
param blocklistApiSecret = readEnvironmentVariable('BLOCKLIST_API_SECRET', '')

param mysqlDatabase = readEnvironmentVariable('DB_DATABASE', 'anonaddy')
param mysqlUsername = readEnvironmentVariable('DB_USERNAME', 'anonaddy')
param mysqlPassword = readEnvironmentVariable('DB_PASSWORD', '')
param mysqlRootPassword = readEnvironmentVariable('MYSQL_ROOT_PASSWORD', '')

param mailFromName = readEnvironmentVariable('MAIL_FROM_NAME', 'AnonAddy')
param mailAcsEndpoint = readEnvironmentVariable('MAIL_ACS_ENDPOINT', '')
param mailAcsAccessKey = readEnvironmentVariable('MAIL_ACS_ACCESS_KEY', '')
param mailAcsEmailDomainName = readEnvironmentVariable('MAIL_ACS_EMAIL_DOMAIN_NAME', 'anon.bc3.tech')
param mailAcsSenderUsername = readEnvironmentVariable('MAIL_ACS_SENDER_USERNAME', 'reply-to-sender')
param appImageName = readEnvironmentVariable('SERVICE_APP_IMAGE_NAME', 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest')
param mailImageName = readEnvironmentVariable('SERVICE_MAIL_IMAGE_NAME', 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest')
