$ErrorActionPreference = 'Stop'

Write-Host 'Loading azd environment variables...'
$azdEnvValues = azd env get-values
foreach ($line in $azdEnvValues) {
    if ([string]::IsNullOrWhiteSpace($line) -or -not $line.Contains('=')) {
        continue
    }

    $parts = $line.Split('=', 2)
    $key = $parts[0]
    $value = $parts[1].Trim('"')
    Set-Item -Path "Env:$key" -Value $value
}

$resourceGroupName = $env:RESOURCE_GROUP_NAME
$appContainerAppName = $env:APP_CONTAINER_APP_NAME
$appCustomDomain = $env:APP_CUSTOM_DOMAIN
$containerAppEnvironmentName = $env:CONTAINER_APP_ENVIRONMENT_NAME

if ([string]::IsNullOrWhiteSpace($resourceGroupName) -or [string]::IsNullOrWhiteSpace($appContainerAppName) -or [string]::IsNullOrWhiteSpace($appCustomDomain) -or [string]::IsNullOrWhiteSpace($containerAppEnvironmentName)) {
    throw 'RESOURCE_GROUP_NAME, APP_CONTAINER_APP_NAME, APP_CUSTOM_DOMAIN, and CONTAINER_APP_ENVIRONMENT_NAME must be available in azd environment.'
}

Write-Host "Binding custom domain '$appCustomDomain' to '$appContainerAppName'..."
az containerapp hostname bind `
    --resource-group $resourceGroupName `
    --name $appContainerAppName `
    --hostname $appCustomDomain `
    --environment $containerAppEnvironmentName `
    --only-show-errors | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Failed to bind custom domain '$appCustomDomain'."
}

Write-Host 'Custom domain binding ensured.'
