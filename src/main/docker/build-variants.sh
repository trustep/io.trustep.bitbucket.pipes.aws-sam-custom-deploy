#!/usr/bin/env bash
# Construye (y opcionalmente publica) todas las variantes definidas en variants.json.
# Uso:
#   build-variants.sh <feature|develop|release|main> [--push]
# Variables de entorno requeridas:
#   DOCKER_HUB_USERNAME, NEXT_RELEASE_BASE_VERSION, BITBUCKET_REPO_SLUG
# feature: FEATURE_STACK_NAME
# develop: DEV_TIMESTAMP
set -euo pipefail

KIND="${1:?kind requerido: feature|develop|release|main}"
MODE="build"
if [[ "${2:-}" == "--push" ]]; then
  MODE="build-push"
elif [[ "${2:-}" == "--push-only" ]]; then
  MODE="push-only"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VARIANTS_FILE="${SCRIPT_DIR}/variants.json"
DOCKERFILE="${SCRIPT_DIR}/Dockerfile"

: "${DOCKER_HUB_USERNAME:?}"
: "${NEXT_RELEASE_BASE_VERSION:?}"
: "${BITBUCKET_REPO_SLUG:?}"

if [[ "${KIND}" == "feature" ]]; then
  : "${FEATURE_STACK_NAME:?}"
fi
if [[ "${KIND}" == "develop" ]]; then
  : "${DEV_TIMESTAMP:?}"
fi

mapfile -t VARIANT_LINES < <(python3 - "${VARIANTS_FILE}" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    data = json.load(f)
for v in data["variants"]:
    print("|".join([
        v["id"],
        v.get("suffix") or "",
        v["base_image"],
        "true" if v.get("install_nvm") else "false",
    ]))
PY
)

image_tag_for_suffix() {
  local suffix="$1"
  case "${KIND}" in
    feature)
      echo "${BITBUCKET_REPO_SLUG}:${NEXT_RELEASE_BASE_VERSION}${suffix}-feat-${FEATURE_STACK_NAME}"
      ;;
    develop)
      echo "${BITBUCKET_REPO_SLUG}:${NEXT_RELEASE_BASE_VERSION}${suffix}-${DEV_TIMESTAMP}"
      ;;
    release)
      echo "${BITBUCKET_REPO_SLUG}:${NEXT_RELEASE_BASE_VERSION}${suffix}"
      ;;
    main)
      echo "${BITBUCKET_REPO_SLUG}:latest${suffix}"
      ;;
    *)
      echo "kind desconocido: ${KIND}" >&2
      exit 1
      ;;
  esac
}

cd "${SCRIPT_DIR}"

for line in "${VARIANT_LINES[@]}"; do
  IFS='|' read -r VID SUFFIX BASE INSTALL_NVM <<<"${line}"
  TAG="$(image_tag_for_suffix "${SUFFIX}")"
  FULL_TAG="${DOCKER_HUB_USERNAME}/${TAG}"
  if [[ "${MODE}" != "push-only" ]]; then
    echo "Building variant id=${VID} base=${BASE} install_nvm=${INSTALL_NVM} tag=${FULL_TAG}"
    docker build . --file "${DOCKERFILE}" \
      --build-arg "SAM_CLI_VERSION=${NEXT_RELEASE_BASE_VERSION}" \
      --build-arg "SAM_BASE_IMAGE=${BASE}" \
      --build-arg "INSTALL_NVM=${INSTALL_NVM}" \
      --tag "${FULL_TAG}"
  fi
  if [[ "${MODE}" == "build-push" || "${MODE}" == "push-only" ]]; then
    echo "Pushing ${FULL_TAG}"
    docker push "${FULL_TAG}"
  fi
done
