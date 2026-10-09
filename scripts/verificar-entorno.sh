#!/usr/bin/env bash
# Comprueba que tu entorno está listo para el taller de CI/CD con GitHub, Terraform y Azure.
set -u

ok=0
fallos=0

comprobar() {
  local etiqueta="$1"
  local comando="$2"
  if eval "$comando" >/dev/null 2>&1; then
    echo "  [OK]    $etiqueta"
    ok=$((ok + 1))
  else
    echo "  [FALLA] $etiqueta"
    fallos=$((fallos + 1))
  fi
}

echo ""
echo "Verificando el entorno del taller"
echo "---------------------------------"

comprobar "Git instalado"               "git --version"
comprobar "GitHub CLI instalado"        "gh --version"
comprobar "Sesion de GitHub CLI"        "gh auth token"
comprobar "Node.js 22 o superior"       "node -e 'process.exit(Number(process.versions.node.split(\".\")[0]) >= 22 ? 0 : 1)'"
comprobar "Terraform instalado"         "terraform version"
comprobar "Azure CLI instalado"         "az version"
comprobar "Sesion de Azure CLI"         "az account show"
comprobar "Pruebas de la app"           "(cd app && npm test)"
comprobar "Terraform: formato"          "terraform -chdir=infra fmt -check -recursive"
comprobar "Terraform: init sin backend" "terraform -chdir=infra init -backend=false"
comprobar "Terraform: validate"         "terraform -chdir=infra validate"

echo "---------------------------------"
echo "  Correctas: $ok   Fallidas: $fallos"
echo ""

if [ "$fallos" -gt 0 ]; then
  echo "Revisa el Modulo 0 del README antes de continuar."
  exit 1
fi

echo "Todo listo. Sigue con el Modulo 1 del README."
