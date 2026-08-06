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
$migrateJobName = $env:MIGRATE_CONTAINER_APP_JOB_NAME
$appContainerAppName = $env:APP_CONTAINER_APP_NAME

if ([string]::IsNullOrWhiteSpace($resourceGroupName) -or [string]::IsNullOrWhiteSpace($migrateJobName) -or [string]::IsNullOrWhiteSpace($appContainerAppName)) {
    throw 'RESOURCE_GROUP_NAME, MIGRATE_CONTAINER_APP_JOB_NAME, and APP_CONTAINER_APP_NAME must be available in azd environment.'
}

$appImageName = $env:SERVICE_APP_IMAGE_NAME
if ([string]::IsNullOrWhiteSpace($appImageName)) {
    $appImageName = az containerapp show `
        --resource-group $resourceGroupName `
        --name $appContainerAppName `
        --query 'properties.template.containers[0].image' `
        --output tsv
}

if ([string]::IsNullOrWhiteSpace($appImageName)) {
    throw 'Unable to resolve app image for migration job.'
}

Write-Host "Updating migration job image to '$appImageName'..."
az containerapp job update `
    --resource-group $resourceGroupName `
    --name $migrateJobName `
    --image $appImageName `
    --container-name migrate `
    --only-show-errors | Out-Null

Write-Host "Starting migration job '$migrateJobName' in '$resourceGroupName'..."
$executionName = az containerapp job start `
    --resource-group $resourceGroupName `
    --name $migrateJobName `
    --query name `
    --output tsv

if ([string]::IsNullOrWhiteSpace($executionName)) {
    throw "Failed to start migration job '$migrateJobName'."
}

Write-Host "Waiting for migration execution '$executionName'..."
for ($attempt = 0; $attempt -lt 120; $attempt++) {
    $status = az containerapp job execution show `
        --resource-group $resourceGroupName `
        --name $migrateJobName `
        --job-execution-name $executionName `
        --query properties.status `
        --output tsv

    if ($status -eq 'Succeeded') {
        Write-Host 'Migrations completed successfully.'
        exit 0
    }

    if ($status -eq 'Failed') {
        throw "Migration execution '$executionName' failed."
    }

    Start-Sleep -Seconds 5
}

throw "Timed out waiting for migration execution '$executionName' to complete."
