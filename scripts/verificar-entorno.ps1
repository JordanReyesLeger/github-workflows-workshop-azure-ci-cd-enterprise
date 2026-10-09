<#
.SYNOPSIS
    Comprueba que tu entorno esta listo para el taller de CI/CD con GitHub, Terraform y Azure.
#>

$ErrorActionPreference = 'Continue'
$correctas = 0
$fallidas = 0

function Test-Paso {
    param([string]$Etiqueta, [scriptblock]$Comando)

    & $Comando *> $null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK]    $Etiqueta" -ForegroundColor Green
        $script:correctas++
    }
    else {
        Write-Host "  [FALLA] $Etiqueta" -ForegroundColor Red
        $script:fallidas++
    }
}

Write-Host ""
Write-Host "Verificando el entorno del taller" -ForegroundColor Cyan
Write-Host "---------------------------------"

Test-Paso "Git instalado"                 { git --version }
Test-Paso "GitHub CLI instalado"          { gh --version }
Test-Paso "Sesion de GitHub CLI"          { gh auth token }
Test-Paso "Node.js 22 o superior"         { node -e "process.exit(Number(process.versions.node.split('.')[0]) >= 22 ? 0 : 1)" }
Test-Paso "Terraform instalado"           { terraform version }
Test-Paso "Azure CLI instalado"           { az version }
Test-Paso "Sesion de Azure CLI"           { az account show }
Test-Paso "Pruebas de la app"             { npm --prefix app test }
Test-Paso "Terraform: formato"            { terraform -chdir=infra fmt -check -recursive }
Test-Paso "Terraform: init sin backend"   { terraform -chdir=infra init -backend=false }
Test-Paso "Terraform: validate"           { terraform -chdir=infra validate }

Write-Host "---------------------------------"
Write-Host "  Correctas: $correctas   Fallidas: $fallidas"
Write-Host ""

if ($fallidas -gt 0) {
    Write-Host "Revisa el Modulo 0 del README antes de continuar." -ForegroundColor Yellow
    exit 1
}

Write-Host "Todo listo. Sigue con el Modulo 1 del README." -ForegroundColor Green
