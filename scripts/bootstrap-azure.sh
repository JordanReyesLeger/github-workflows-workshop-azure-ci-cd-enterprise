#!/usr/bin/env bash
# Prepara Azure y GitHub para el taller: estado remoto de Terraform + identidad OIDC.
#
# Es idempotente: puedes ejecutarlo varias veces. Crea (o reutiliza):
#   1. Un grupo de recursos y una cuenta de almacenamiento para el estado de Terraform.
#   2. Un registro de aplicacion de Entra ID con credenciales federadas para GitHub
#      (cero secretos: GitHub pide un token temporal a Azure en cada ejecucion).
#   3. Los roles minimos para que el pipeline despliegue.
#   4. Las variables del repositorio en GitHub.
#
# Uso:
#   bash scripts/bootstrap-azure.sh ORG/REPO SUSCRIPCION_ID [NOMBRE_APP] [UBICACION] [clave=valor ...]
#
# Ejemplo:
#   bash scripts/bootstrap-azure.sh mi-org/taller-azure-ana 00000000-0000-0000-0000-000000000000 anabiker eastus2

set -euo pipefail

REPO="${1:-}"
SUSCRIPCION="${2:-}"
NOMBRE_APP="${3:-contosobiker}"
UBICACION="${4:-eastus2}"
shift $(( $# < 4 ? $# : 4 ))
ETIQUETAS=("$@")

if [[ ! "$REPO" =~ ^[^/[:space:]]+/[^/[:space:]]+$ ]] || [[ ! "$SUSCRIPCION" =~ ^[0-9a-fA-F-]{36}$ ]]; then
  echo "Uso: bash scripts/bootstrap-azure.sh ORG/REPO SUSCRIPCION_ID [NOMBRE_APP] [UBICACION] [clave=valor ...]" >&2
  exit 1
fi
if [[ ! "$NOMBRE_APP" =~ ^[a-z0-9]{3,12}$ ]]; then
  echo "NOMBRE_APP: de 3 a 12 caracteres, solo minusculas y numeros." >&2
  exit 1
fi

paso() { printf '\n==> %s\n' "$1"; }

paso "Suscripcion $SUSCRIPCION"
az account set --subscription "$SUSCRIPCION"
TENANT_ID="$(az account show --query tenantId -o tsv)"
MI_ID="$(az ad signed-in-user show --query id -o tsv)"
echo "Tenant: $TENANT_ID"

# ---------------------------------------------------------------- Estado remoto
HASH="$(printf '%s' "$SUSCRIPCION-$NOMBRE_APP" | sha1sum | cut -c1-6)"
RG_ESTADO="rg-tfstate-$NOMBRE_APP"
CUENTA_ESTADO="sttf${NOMBRE_APP}${HASH}"
CONTENEDOR="tfstate"
TAGS=("proyecto=$NOMBRE_APP" "proposito=tfstate" ${ETIQUETAS[@]+"${ETIQUETAS[@]}"})

paso "Estado remoto: $CUENTA_ESTADO"
az group create --name "$RG_ESTADO" --location "$UBICACION" --tags "${TAGS[@]}" -o none
az storage account create --name "$CUENTA_ESTADO" --resource-group "$RG_ESTADO" --location "$UBICACION" \
  --sku Standard_LRS --kind StorageV2 --min-tls-version TLS1_2 \
  --allow-blob-public-access false --allow-shared-key-access false --public-network-access Enabled \
  --tags "${TAGS[@]}" -o none
az storage account blob-service-properties update --account-name "$CUENTA_ESTADO" --resource-group "$RG_ESTADO" \
  --enable-versioning true --enable-delete-retention true --delete-retention-days 14 -o none

ID_CUENTA="$(az storage account show --name "$CUENTA_ESTADO" --resource-group "$RG_ESTADO" --query id -o tsv)"

# Yo tambien necesito acceso de datos para crear el contenedor (Owner no lo incluye).
if [ -z "$(az role assignment list --assignee "$MI_ID" --scope "$ID_CUENTA" --role 'Storage Blob Data Contributor' --query '[0].id' -o tsv)" ]; then
  az role assignment create --assignee-object-id "$MI_ID" --assignee-principal-type User \
    --role 'Storage Blob Data Contributor' --scope "$ID_CUENTA" -o none
fi

echo "Creando el contenedor (el rol puede tardar un minuto en propagarse)..."
creado=0
for _ in $(seq 1 12); do
  if az storage container create --name "$CONTENEDOR" --account-name "$CUENTA_ESTADO" --auth-mode login -o none 2>/dev/null; then
    creado=1; break
  fi
  sleep 10
done
[ "$creado" -eq 1 ] || { echo "No se pudo crear el contenedor $CONTENEDOR" >&2; exit 1; }

# ---------------------------------------------------------------- Identidad OIDC
NOMBRE_ENTRA="gh-${REPO//\//-}"
paso "Identidad de Entra ID: $NOMBRE_ENTRA"

CLIENT_ID="$(az ad app list --display-name "$NOMBRE_ENTRA" --query '[0].appId' -o tsv)"
[ -n "$CLIENT_ID" ] || CLIENT_ID="$(az ad app create --display-name "$NOMBRE_ENTRA" --query appId -o tsv)"
OBJETO_APP="$(az ad app show --id "$CLIENT_ID" --query id -o tsv)"

SP_ID="$(az ad sp list --filter "appId eq '$CLIENT_ID'" --query '[0].id' -o tsv)"
[ -n "$SP_ID" ] || SP_ID="$(az ad sp create --id "$CLIENT_ID" --query id -o tsv)"

EXISTENTES="$(az ad app federated-credential list --id "$OBJETO_APP" --query '[].name' -o tsv | tr -d '\r')"

# GitHub puede emitir el "subject" con IDs inmutables (repo:ORG@id/REPO@id) en vez de nombres.
# Se lo preguntamos al repositorio para que la credencial coincida exactamente con lo que llegue.
PREFIJO="repo:${REPO}"
if command -v gh >/dev/null 2>&1; then
  CONSULTADO="$(gh api "repos/${REPO}/actions/oidc/customization/sub" --jq .sub_claim_prefix 2>/dev/null || true)"
  [ -z "$CONSULTADO" ] || PREFIJO="$CONSULTADO"
fi
echo "Subject OIDC: $PREFIJO"

credencial() {
  local nombre="$1" subject="$2" archivo
  archivo="$(mktemp)"
  printf '{"name":"%s","issuer":"https://token.actions.githubusercontent.com","subject":"%s","audiences":["api://AzureADTokenExchange"]}' \
    "$nombre" "$subject" > "$archivo"
  if grep -qx "$nombre" <<<"$EXISTENTES"; then
    az ad app federated-credential update --id "$OBJETO_APP" --federated-credential-id "$nombre" --parameters "@$archivo" -o none
    echo "  ~ $nombre -> $subject"
  else
    az ad app federated-credential create --id "$OBJETO_APP" --parameters "@$archivo" -o none
    echo "  + $nombre -> $subject"
  fi
  rm -f "$archivo"
}
credencial github-pull-request "${PREFIJO}:pull_request"
credencial github-rama-main    "${PREFIJO}:ref:refs/heads/main"
credencial github-entorno-dev  "${PREFIJO}:environment:dev"
credencial github-entorno-prod "${PREFIJO}:environment:prod"

# ---------------------------------------------------------------- Roles
paso "Roles del pipeline"
ALCANCE="/subscriptions/$SUSCRIPCION"
for rol in "Contributor" "Storage Blob Data Contributor"; do
  if [ -n "$(az role assignment list --assignee "$SP_ID" --scope "$ALCANCE" --role "$rol" --query '[0].id' -o tsv)" ]; then
    echo "  = $rol (ya existia)"; continue
  fi
  # La identidad recien creada puede tardar en replicarse en Entra ID.
  asignado=0
  for _ in $(seq 1 6); do
    if az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
         --role "$rol" --scope "$ALCANCE" -o none 2>/dev/null; then
      asignado=1; echo "  + $rol"; break
    fi
    sleep 10
  done
  [ "$asignado" -eq 1 ] || { echo "No se pudo asignar el rol $rol" >&2; exit 1; }
done

# ---------------------------------------------------------------- GitHub
ETIQUETAS_JSON="{}"
if [ "${#ETIQUETAS[@]}" -gt 0 ]; then
  ETIQUETAS_JSON="{"
  sep=""
  for e in "${ETIQUETAS[@]}"; do
    ETIQUETAS_JSON+="${sep}\"${e%%=*}\":\"${e#*=}\""
    sep=","
  done
  ETIQUETAS_JSON+="}"
fi

declare -a NOMBRES=(AZURE_CLIENT_ID AZURE_TENANT_ID AZURE_SUBSCRIPTION_ID TFSTATE_RESOURCE_GROUP TFSTATE_STORAGE_ACCOUNT TFSTATE_CONTAINER NOMBRE_APP UBICACION ETIQUETAS_EXTRA)
declare -a VALORES=("$CLIENT_ID" "$TENANT_ID" "$SUSCRIPCION" "$RG_ESTADO" "$CUENTA_ESTADO" "$CONTENEDOR" "$NOMBRE_APP" "$UBICACION" "$ETIQUETAS_JSON")

if command -v gh >/dev/null 2>&1; then
  paso "Variables del repositorio $REPO"
  for i in "${!NOMBRES[@]}"; do
    gh variable set "${NOMBRES[$i]}" --body "${VALORES[$i]}" --repo "$REPO"
    echo "  + ${NOMBRES[$i]}"
  done
else
  paso "Crea estas variables a mano (Settings > Secrets and variables > Actions > Variables)"
fi

printf '\nLISTO\n'
for i in "${!NOMBRES[@]}"; do printf '  %-26s %s\n' "${NOMBRES[$i]}" "${VALORES[$i]}"; done
printf '\nNo se creo ningun secreto: la autenticacion es OIDC.\n'
