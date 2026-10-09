<#
.SYNOPSIS
    Crea TU copia del taller dentro de tu organizacion y sube el codigo.

.DESCRIPTION
    Funciona con Windows PowerShell 5.1 y con PowerShell 7, y tambien con
    cuentas Enterprise Managed User (EMU), que no pueden usar
    "Use this template" contra repositorios de fuera de la empresa.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\crear-mi-repo.ps1 -Organizacion mi-org -Nombre taller-azure-ana
#>
param(
    [Parameter(Mandatory = $true)][string]$Organizacion,
    [Parameter(Mandatory = $true)][string]$Nombre,
    [ValidateSet('private', 'internal', 'public')][string]$Visibilidad = 'private',
    [string]$Origen = 'JordanReyesLeger/github-workflows-workshop-azure-ci-cd-enterprise',
    [string]$Rama = 'main'
)

# Sin 'Stop' global: en PowerShell 5.1 convierte la salida normal de gh y git en errores.
$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Paso($n, $t) { Write-Host ""; Write-Host "[$n] $t" -ForegroundColor Cyan }
function Fallo($t)    { Write-Host ""; Write-Host "ERROR: $t" -ForegroundColor Red; exit 1 }

Paso 0 "Comprobando herramientas y sesion..."
foreach ($cmd in 'git', 'gh') {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { Fallo "Falta '$cmd'. Instalalo y abre una terminal nueva." }
}

$usuario = (gh api user --jq .login 2>$null)
if ($LASTEXITCODE -ne 0 -or -not $usuario) { Fallo "No has iniciado sesion en GitHub CLI. Ejecuta: gh auth login" }
Write-Host "    Sesion de GitHub: $usuario"
# Para que 'git push' use esta misma cuenta y no otra guardada en el equipo.
gh auth setup-git 2>$null

$null = (gh repo view "$Organizacion/$Nombre" --json name 2>$null)
if ($LASTEXITCODE -eq 0) {
    Fallo "El repositorio $Organizacion/$Nombre YA EXISTE. Usa otro nombre, o si es tuyo, clonalo con: gh repo clone $Organizacion/$Nombre"
}

$destino = Join-Path (Get-Location).Path $Nombre
if (Test-Path $destino) { Fallo "Ya existe la carpeta '$destino'. Borrala o usa otro nombre." }

Paso 1 "Descargando el contenido del taller..."
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("taller-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
$zip = Join-Path $tmp 'taller.zip'
try {
    # Sin credenciales: la descarga es anonima, asi una cuenta EMU no interviene.
    Invoke-WebRequest -Uri "https://codeload.github.com/$Origen/zip/refs/heads/$Rama" -OutFile $zip -UseBasicParsing -ErrorAction Stop
    Expand-Archive -Path $zip -DestinationPath $tmp -Force -ErrorAction Stop
} catch {
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
    Fallo "No se pudo descargar el taller: $($_.Exception.Message)"
}
$extraido = Get-ChildItem -Path $tmp -Directory | Select-Object -First 1
Move-Item -Path $extraido.FullName -Destination $destino
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue

Paso 2 "Preparando el repositorio local..."
Push-Location $destino

# CODEOWNERS trae un marcador: lo reemplazamos por tu usuario para que la revision de codigo funcione.
$codeowners = Join-Path $destino '.github/CODEOWNERS'
if (Test-Path $codeowners) {
    (Get-Content $codeowners -Raw).Replace('@TU_USUARIO', "@$usuario") | Set-Content -Path $codeowners -NoNewline
}

git init -q -b $Rama
git add -A
# Si git no tiene nombre y correo configurados, usa los de tu cuenta de GitHub.
$identidad = @()
if (-not (git config user.email)) { $identidad += @('-c', "user.email=$usuario@users.noreply.github.com") }
if (-not (git config user.name))  { $identidad += @('-c', "user.name=$usuario") }
git @identidad commit -q -m "chore: taller de CI/CD con GitHub, Terraform y Azure"
if ($LASTEXITCODE -ne 0) { Pop-Location; Fallo "No se pudo crear el commit inicial." }

Paso 3 "Creando $Organizacion/$Nombre ($Visibilidad) y subiendo el codigo..."
gh repo create "$Organizacion/$Nombre" "--$Visibilidad" --source=. --push
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Fallo "No se pudo crear el repositorio. Comprueba que puedes crear repos en '$Organizacion'."
}
Pop-Location

Write-Host ""
Write-Host "LISTO" -ForegroundColor Green
Write-Host "  Repositorio : https://github.com/$Organizacion/$Nombre"
Write-Host "  Carpeta     : $destino"
Write-Host ""
Write-Host "Siguiente paso:  cd $Nombre   y continua con el Modulo 0 del README."
Write-Host ""
