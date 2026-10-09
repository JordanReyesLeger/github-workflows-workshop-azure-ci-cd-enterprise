#!/usr/bin/env bash
# Crea TU copia del taller dentro de tu organizacion y sube el codigo.
#
# Funciona tambien con cuentas Enterprise Managed User (EMU), que no pueden
# usar "Use this template" contra repositorios de fuera de la empresa.
#
# Uso:
#   bash scripts/crear-mi-repo.sh ORGANIZACION NOMBRE [private|internal|public]

set -euo pipefail

ORGANIZACION="${1:-}"
NOMBRE="${2:-}"
VISIBILIDAD="${3:-private}"
ORIGEN="${ORIGEN:-JordanReyesLeger/github-workflows-workshop-azure-ci-cd-enterprise}"
RAMA="${RAMA:-main}"

if [ -z "$ORGANIZACION" ] || [ -z "$NOMBRE" ]; then
  echo "Uso: bash scripts/crear-mi-repo.sh ORGANIZACION NOMBRE [private|internal|public]" >&2
  exit 1
fi

for cmd in git gh curl unzip; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Falta $cmd. Instalalo antes de continuar." >&2; exit 1; }
done

USUARIO="$(gh api user --jq .login 2>/dev/null)" || { echo "No has iniciado sesion. Ejecuta: gh auth login" >&2; exit 1; }
echo "Sesion de GitHub: $USUARIO"
# Para que 'git push' use esta misma cuenta y no otra guardada en el equipo.
gh auth setup-git >/dev/null 2>&1 || true
if gh repo view "$ORGANIZACION/$NOMBRE" --json name >/dev/null 2>&1; then
  echo "El repositorio $ORGANIZACION/$NOMBRE YA EXISTE. Usa otro nombre, o si es tuyo: gh repo clone $ORGANIZACION/$NOMBRE" >&2
  exit 1
fi
if [ -e "$NOMBRE" ]; then echo "Ya existe la carpeta '$NOMBRE'. Borrala o usa otro nombre." >&2; exit 1; fi

echo ""
echo "[1] Descargando el contenido del taller..."
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
# Sin credenciales: evita que un token EMU intervenga en la descarga.
curl -fsSL -o "$TMP/taller.zip" "https://codeload.github.com/$ORIGEN/zip/refs/heads/$RAMA"
unzip -q "$TMP/taller.zip" -d "$TMP"
mv "$TMP"/*-"$RAMA" "$NOMBRE"

echo "[2] Preparando el repositorio local..."
cd "$NOMBRE"
# CODEOWNERS trae un marcador: lo reemplazamos por tu usuario.
if [ -f .github/CODEOWNERS ]; then
  sed "s/@TU_USUARIO/@$USUARIO/g" .github/CODEOWNERS > .github/CODEOWNERS.tmp
  mv .github/CODEOWNERS.tmp .github/CODEOWNERS
fi
git init -q -b "$RAMA"
git add -A
# Si git no tiene nombre y correo configurados, usa los de tu cuenta de GitHub.
IDENTIDAD=()
git config user.email >/dev/null || IDENTIDAD+=(-c "user.email=$USUARIO@users.noreply.github.com")
git config user.name  >/dev/null || IDENTIDAD+=(-c "user.name=$USUARIO")
git ${IDENTIDAD[@]+"${IDENTIDAD[@]}"} commit -q -m "chore: taller de CI/CD con GitHub, Terraform y Azure"

echo "[3] Creando $ORGANIZACION/$NOMBRE y subiendo..."
gh repo create "$ORGANIZACION/$NOMBRE" "--$VISIBILIDAD" --source=. --push

echo ""
echo "Listo."
echo "  Repositorio : https://github.com/$ORGANIZACION/$NOMBRE"
echo "  Carpeta     : $(pwd)"
echo ""
echo "Sigue con el Modulo 0 del README."
