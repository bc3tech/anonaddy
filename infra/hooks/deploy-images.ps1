[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

function Get-AzdValue {
    param([Parameter(Mandatory = $true)][string] $Name)

    $value = azd env get-value $Name
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($value)) {
        throw "Missing azd environment value '$Name'. Run 'azd provision' first."
    }

    return $value.Trim().Trim('"')
}

$registryEndpoint = Get-AzdValue 'AZURE_CONTAINER_REGISTRY_ENDPOINT'
$resourceGroupName = Get-AzdValue 'RESOURCE_GROUP_NAME'
$appName = Get-AzdValue 'APP_CONTAINER_APP_NAME'
$mailName = Get-AzdValue 'MAIL_CONTAINER_APP_NAME'

$registryName = $registryEndpoint.Split('.')[0]
$platform = if ($env:AZURE_IMAGE_PLATFORM) { $env:AZURE_IMAGE_PLATFORM } else { 'linux/amd64' }

$appImage = "$registryEndpoint/anonaddy-app:$env:AZURE_ENV_NAME"
$mailImage = "$registryEndpoint/anonaddy-mail:$env:AZURE_ENV_NAME"

Write-Host "Logging in to ACR '$registryName'..."
az acr login --name $registryName | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "az acr login failed."
}

Write-Host "Building and pushing app image '$appImage' for $platform..."
docker buildx build --platform $platform --target app-runtime -t $appImage --push .
if ($LASTEXITCODE -ne 0) {
    throw "app image build failed."
}

Write-Host "Building and pushing mail image '$mailImage' for $platform..."
docker buildx build --platform $platform --target mail-runtime -t $mailImage --push .
if ($LASTEXITCODE -ne 0) {
    throw "mail image build failed."
}

Write-Host "Updating app Container App '$appName'..."
az containerapp update `
    --resource-group $resourceGroupName `
    --name $appName `
    --image $appImage `
    --command "sh" "-c" `
    --args "mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/framework/testing storage/logs && php artisan migrate --force && php artisan storage:link --force && /usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "app container update failed."
}

Write-Host "Updating mail Container App '$mailName'..."
az containerapp update `
    --resource-group $resourceGroupName `
    --name $mailName `
    --image $mailImage `
    --command "sh" "-c" `
    --args "mkdir -p /var/www/html/storage/framework/cache /var/www/html/storage/framework/sessions /var/www/html/storage/framework/views /var/www/html/storage/framework/testing /var/www/html/storage/logs && /usr/local/bin/anonaddy-mail-entrypoint" | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "mail container update failed."
}

Write-Host "Enabling external TCP ingress for mail Container App '$mailName'..."
az containerapp ingress enable `
    --resource-group $resourceGroupName `
    --name $mailName `
    --type external `
    --target-port 25 `
    --exposed-port 25 `
    --transport tcp | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "mail ingress enable failed."
}

Write-Host "Deployment images updated."
