<#
.SYNOPSIS
    Prepara Azure y GitHub para el taller: estado remoto de Terraform + identidad OIDC.

.DESCRIPTION
    Crea (o reutiliza, es idempotente):
      1. Un grupo de recursos y una cuenta de almacenamiento para el estado de Terraform.
      2. Un registro de aplicación de Entra ID con credenciales federadas para GitHub
         (cero secretos: GitHub pide un token temporal a Azure en cada ejecución).
      3. Los roles mínimos para que el pipeline despliegue.
      4. Las variables del repositorio en GitHub (si `gh` está autenticado).

.EXAMPLE
    ./scripts/bootstrap-azure.ps1 -Repositorio mi-org/taller-azure-ana -SuscripcionId 00000000-0000-0000-0000-000000000000 -NombreApp anabiker
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [ValidatePattern('^[^/\s]+/[^/\s]+$')] [string] $Repositorio,
    [Parameter(Mandatory)] [ValidatePattern('^[0-9a-fA-F-]{36}$')] [string] $SuscripcionId,
    [ValidatePattern('^[a-z0-9]{3,12}$')] [string] $NombreApp = 'contosobiker',
    [string] $Ubicacion = 'eastus2',
    [string[]] $Etiquetas = @(),
    [switch] $OmitirGitHub
)

$ErrorActionPreference = 'Stop'

function Invoke-Az {
    # Ejecuta az y falla con el mensaje real si algo sale mal.
    $salida = & az @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "az $($args -join ' ') falló:`n$salida" }
    return ($salida | Out-String).Trim()
}

function Escribir-Paso($texto) { Write-Host "`n==> $texto" -ForegroundColor Cyan }

Escribir-Paso "Suscripción $SuscripcionId"
Invoke-Az account set --subscription $SuscripcionId | Out-Null
$tenantId = Invoke-Az account show --query tenantId -o tsv
$miId = Invoke-Az ad signed-in-user show --query id -o tsv
Write-Host "Tenant: $tenantId"

# ---------------------------------------------------------------- Estado remoto
$hash = ([System.BitConverter]::ToString(
        [System.Security.Cryptography.SHA1]::HashData([Text.Encoding]::UTF8.GetBytes("$SuscripcionId-$NombreApp"))
    ) -replace '-', '').ToLower().Substring(0, 6)
$rgEstado = "rg-tfstate-$NombreApp"
$cuentaEstado = "sttf$NombreApp$hash"
$contenedor = 'tfstate'

$etiquetasEstado = @("proyecto=$NombreApp", 'proposito=tfstate') + $Etiquetas

Escribir-Paso "Estado remoto: $cuentaEstado"
Invoke-Az group create --name $rgEstado --location $Ubicacion --tags @etiquetasEstado | Out-Null
Invoke-Az storage account create --name $cuentaEstado --resource-group $rgEstado --location $Ubicacion `
    --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 `
    --allow-blob-public-access false --allow-shared-key-access false --public-network-access Enabled `
    --tags @etiquetasEstado | Out-Null
Invoke-Az storage account blob-service-properties update --account-name $cuentaEstado --resource-group $rgEstado `
    --enable-versioning true --enable-delete-retention true --delete-retention-days 14 | Out-Null

$idCuentaEstado = Invoke-Az storage account show --name $cuentaEstado --resource-group $rgEstado --query id -o tsv

# Yo también necesito acceso de datos para crear el contenedor (Owner no lo incluye).
$existeRol = Invoke-Az role assignment list --assignee $miId --scope $idCuentaEstado --role 'Storage Blob Data Contributor' --query '[0].id' -o tsv
if (-not $existeRol) {
    Invoke-Az role assignment create --assignee-object-id $miId --assignee-principal-type User `
        --role 'Storage Blob Data Contributor' --scope $idCuentaEstado | Out-Null
}

Write-Host "Creando el contenedor (el rol puede tardar un minuto en propagarse)..."
$creado = $false
for ($i = 1; $i -le 12 -and -not $creado; $i++) {
    & az storage container create --name $contenedor --account-name $cuentaEstado --auth-mode login 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) { $creado = $true } else { Start-Sleep -Seconds 10 }
}
if (-not $creado) { throw "No se pudo crear el contenedor $contenedor" }

# ---------------------------------------------------------------- Identidad OIDC
$nombreEntra = "gh-$($Repositorio -replace '/', '-')"
Escribir-Paso "Identidad de Entra ID: $nombreEntra"

$clientId = Invoke-Az ad app list --display-name $nombreEntra --query '[0].appId' -o tsv
if (-not $clientId) {
    $clientId = Invoke-Az ad app create --display-name $nombreEntra --query appId -o tsv
}
$objetoApp = Invoke-Az ad app show --id $clientId --query id -o tsv

$spId = Invoke-Az ad sp list --filter "appId eq '$clientId'" --query '[0].id' -o tsv
if (-not $spId) {
    $spId = Invoke-Az ad sp create --id $clientId --query id -o tsv
}

# GitHub puede emitir el "subject" con IDs inmutables (repo:ORG@id/REPO@id) en vez de nombres.
# Se lo preguntamos al repositorio para que la credencial coincida exactamente con lo que llegue.
$prefijo = "repo:$Repositorio"
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $consultado = (& gh api "repos/$Repositorio/actions/oidc/customization/sub" --jq .sub_claim_prefix 2>$null)
    if ($LASTEXITCODE -eq 0 -and $consultado) { $prefijo = $consultado.Trim() }
}
Write-Host "Subject OIDC: $prefijo"

$subjects = [ordered]@{
    'github-pull-request' = "${prefijo}:pull_request"
    'github-rama-main'    = "${prefijo}:ref:refs/heads/main"
    'github-entorno-dev'  = "${prefijo}:environment:dev"
    'github-entorno-prod' = "${prefijo}:environment:prod"
}
$existentes = (Invoke-Az ad app federated-credential list --id $objetoApp --query '[].name' -o tsv) -split "`n" | ForEach-Object { $_.Trim() }
foreach ($nombre in $subjects.Keys) {
    $cuerpo = @{
        name      = $nombre
        issuer    = 'https://token.actions.githubusercontent.com'
        subject   = $subjects[$nombre]
        audiences = @('api://AzureADTokenExchange')
    } | ConvertTo-Json
    $archivo = New-TemporaryFile
    Set-Content -Path $archivo -Value $cuerpo
    try {
        if ($existentes -contains $nombre) {
            Invoke-Az ad app federated-credential update --id $objetoApp --federated-credential-id $nombre --parameters "@$archivo" | Out-Null
            Write-Host "  ~ $nombre -> $($subjects[$nombre])"
        }
        else {
            Invoke-Az ad app federated-credential create --id $objetoApp --parameters "@$archivo" | Out-Null
            Write-Host "  + $nombre -> $($subjects[$nombre])"
        }
    }
    finally { Remove-Item $archivo -Force }
}

# ---------------------------------------------------------------- Roles
Escribir-Paso 'Roles del pipeline'
$alcance = "/subscriptions/$SuscripcionId"
foreach ($rol in 'Contributor', 'Storage Blob Data Contributor') {
    $tiene = Invoke-Az role assignment list --assignee $spId --scope $alcance --role $rol --query '[0].id' -o tsv
    if ($tiene) { Write-Host "  = $rol (ya existía)"; continue }
    # La identidad recién creada puede tardar en replicarse en Entra ID.
    for ($i = 1; $i -le 6; $i++) {
        & az role assignment create --assignee-object-id $spId --assignee-principal-type ServicePrincipal `
            --role $rol --scope $alcance 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Host "  + $rol"; break }
        if ($i -eq 6) { throw "No se pudo asignar el rol $rol" }
        Start-Sleep -Seconds 10
    }
}

# ---------------------------------------------------------------- GitHub
$mapaEtiquetas = @{}
foreach ($e in $Etiquetas) { $k, $v = $e -split '=', 2; $mapaEtiquetas[$k] = $v }
$etiquetasJson = if ($mapaEtiquetas.Count) { $mapaEtiquetas | ConvertTo-Json -Compress } else { '{}' }
$variables = [ordered]@{
    AZURE_CLIENT_ID       = $clientId
    AZURE_TENANT_ID       = $tenantId
    AZURE_SUBSCRIPTION_ID = $SuscripcionId
    TFSTATE_RESOURCE_GROUP  = $rgEstado
    TFSTATE_STORAGE_ACCOUNT = $cuentaEstado
    TFSTATE_CONTAINER       = $contenedor
    NOMBRE_APP              = $NombreApp
    UBICACION               = $Ubicacion
    ETIQUETAS_EXTRA         = $etiquetasJson
}

if (-not $OmitirGitHub -and (Get-Command gh -ErrorAction SilentlyContinue)) {
    Escribir-Paso "Variables del repositorio $Repositorio"
    foreach ($nombre in $variables.Keys) {
        & gh variable set $nombre --body $variables[$nombre] --repo $Repositorio
        if ($LASTEXITCODE -ne 0) { throw "gh no pudo crear la variable $nombre" }
        Write-Host "  + $nombre"
    }
}
else {
    Escribir-Paso 'Crea estas variables a mano (Settings > Secrets and variables > Actions > Variables)'
}

Write-Host "`nLISTO" -ForegroundColor Green
$variables.GetEnumerator() | ForEach-Object { Write-Host ("  {0,-26} {1}" -f $_.Key, $_.Value) }
Write-Host "`nNo se creó ningún secreto: la autenticación es OIDC." -ForegroundColor Green
