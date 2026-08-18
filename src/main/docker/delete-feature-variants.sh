#!/usr/bin/env bash
# Elimina del Docker Hub las imagenes feature de todas las variantes.
# Variables: DOCKER_HUB_USERNAME, DOCKER_HUB_PERSONAL_ACCESS_TOKEN,
#            NEXT_RELEASE_BASE_VERSION, FEATURE_STACK_NAME, BITBUCKET_REPO_SLUG
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARIANTS_FILE="${SCRIPT_DIR}/variants.json"

: "${DOCKER_HUB_USERNAME:?}"
: "${DOCKER_HUB_PERSONAL_ACCESS_TOKEN:?}"
: "${NEXT_RELEASE_BASE_VERSION:?}"
: "${FEATURE_STACK_NAME:?}"
: "${BITBUCKET_REPO_SLUG:?}"

mapfile -t SUFFIXES < <(python3 - "${VARIANTS_FILE}" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
for v in data["variants"]:
    print(v.get("suffix") or "")
PY
)

echo "Generating Docker Hub Credentials"
DOCKER_HUB_TOKEN=$(curl --proto "=https" --silent -X POST -H "Content-Type: application/json" \
  -d "{\"username\": \"${DOCKER_HUB_USERNAME}\", \"password\": \"${DOCKER_HUB_PERSONAL_ACCESS_TOKEN}\"}" \
  https://hub.docker.com/v2/users/login)
DOCKER_HUB_BEARER=$(echo "${DOCKER_HUB_TOKEN}" | jq -r ".token // empty")
if [ -z "${DOCKER_HUB_BEARER}" ]; then
  echo "No se pudo obtener el token de Docker Hub" >&2
  exit 1
fi

for SUFFIX in "${SUFFIXES[@]}"; do
  TAG="${BITBUCKET_REPO_SLUG}:${NEXT_RELEASE_BASE_VERSION}${SUFFIX}-feat-${FEATURE_STACK_NAME}"
  FULL_TAG="${DOCKER_HUB_USERNAME}/${TAG}"
  echo "Deleting ${FULL_TAG}"
  if ! docker pull "${FULL_TAG}"; then
    echo "Skip (not found): ${FULL_TAG}"
    continue
  fi
  DOCKER_IMAGE_DIGEST=$(docker inspect --format='{{index .RepoDigests 0}}' "${FULL_TAG}" | awk -F"@" '{print $2}')
  if [ -z "${DOCKER_IMAGE_DIGEST}" ]; then
    echo "Skip (sin digest): ${FULL_TAG}"
    continue
  fi
  # Sin --location: la API no redirige y un POST redirigido se degradaria a GET.
  HTTP_CODE=$(curl --proto "=https" --silent --output /dev/null --write-out "%{http_code}" -X POST \
    "https://hub.docker.com/v2/namespaces/${DOCKER_HUB_USERNAME}/delete-images" \
    --header "Authorization: Bearer ${DOCKER_HUB_BEARER}" \
    --header "Content-Type: application/json" \
    -d "{\"dry_run\": false, \"manifests\": [{\"repository\": \"${BITBUCKET_REPO_SLUG}\", \"digest\": \"${DOCKER_IMAGE_DIGEST}\" }]}")
  if [ "${HTTP_CODE}" != "200" ] && [ "${HTTP_CODE}" != "202" ] && [ "${HTTP_CODE}" != "204" ]; then
    echo "Error al eliminar ${FULL_TAG} (HTTP ${HTTP_CODE})" >&2
    exit 1
  fi
done
