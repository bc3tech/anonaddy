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
az containerapp update --resource-group $resourceGroupName --name $appName --image $appImage | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "app container update failed."
}

Write-Host "Updating mail Container App '$mailName'..."
az containerapp update --resource-group $resourceGroupName --name $mailName --image $mailImage | Out-Host
if ($LASTEXITCODE -ne 0) {
    throw "mail container update failed."
}

Write-Host "Deployment images updated."

