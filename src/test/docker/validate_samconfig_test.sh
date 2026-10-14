#!/usr/bin/env bash
# Covers SAM_CONFIG_FILE validation without calling AWS or Docker.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
PIPE_DIR="${ROOT}/src/main/docker/pipe"
VALIDATOR="${PIPE_DIR}/validate_samconfig.py"
FIXTURE="${ROOT}/src/test/docker/resources/samconfig.toml"

failures=0

pass() {
  echo "ok: $1"
}

fail_case() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

expect_fail() {
  local name="$1"
  local path="$2"
  local env_name="$3"
  local delete_flag="$4"
  local needle="$5"
  local output=""
  local status=0

  set +e
  output=$(python3 "${VALIDATOR}" "${path}" "${env_name}" "${delete_flag}" 2>&1)
  status=$?
  set -e

  if [[ "${status}" -eq 0 ]]; then
    fail_case "${name} (exit 0)"
    return
  fi
  if [[ "${output}" != *"${needle}"* ]]; then
    fail_case "${name} (message: ${output})"
    return
  fi
  if [[ "${output}" == *"secret-value"* ]]; then
    fail_case "${name} (leaked secret value)"
    return
  fi
  pass "${name}"
}

expect_ok() {
  local name="$1"
  local path="$2"
  local env_name="$3"
  local delete_flag="$4"
  local output=""
  local status=0

  set +e
  output=$(python3 "${VALIDATOR}" "${path}" "${env_name}" "${delete_flag}" 2>&1)
  status=$?
  set -e

  if [[ "${status}" -ne 0 ]]; then
    fail_case "${name} (exit ${status}: ${output})"
    return
  fi
  if [[ -n "${output}" ]]; then
    fail_case "${name} (unexpected output: ${output})"
    return
  fi
  pass "${name}"
}

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT

cat > "${WORKDIR}/pipeline-custom.toml" <<'EOF'
version = 0.1

[staging.global.parameters]
region = "us-east-1"

[staging.deploy.parameters]
stack_name = "ignored-by-pipe"
capabilities = "CAPABILITY_IAM"
parameter_overrides = "Token=\"secret-value\""
confirm_changeset = false

[staging.local_start_api.parameters]
port = 3000

[default.build.parameters]
cached = true
EOF

before_sum=$(cksum "${WORKDIR}/pipeline-custom.toml")
expect_ok "valid toml with a name other than samconfig.toml" \
  "${WORKDIR}/pipeline-custom.toml" "staging" "false"
after_sum=$(cksum "${WORKDIR}/pipeline-custom.toml")
if [[ "${before_sum}" != "${after_sum}" ]]; then
  fail_case "validator modified the file"
else
  pass "validated file is left unchanged"
fi

expect_ok "qa samconfig.toml fixture" "${FIXTURE}" "qa" "false"
expect_ok "optional sections unused on delete" \
  "${WORKDIR}/pipeline-custom.toml" "staging" "true"

expect_fail "missing file" \
  "${WORKDIR}/no-such.toml" "staging" "false" \
  "SAM config file not found: ${WORKDIR}/no-such.toml"

mkdir -p "${WORKDIR}/not-a-file.toml"
expect_fail "path is not a file" \
  "${WORKDIR}/not-a-file.toml" "staging" "false" \
  "SAM config file is not a file: ${WORKDIR}/not-a-file.toml"

printf 'version = [\n' > "${WORKDIR}/broken.toml"
expect_fail "toml syntax error" \
  "${WORKDIR}/broken.toml" "staging" "false" \
  "SAM config file is not valid TOML: ${WORKDIR}/broken.toml"

cat > "${WORKDIR}/missing-env.toml" <<'EOF'
version = 0.1

[qa.deploy.parameters]
capabilities = "CAPABILITY_IAM"
EOF
expect_fail "required environment missing" \
  "${WORKDIR}/missing-env.toml" "staging" "false" \
  "missing environment table [staging]"

cat > "${WORKDIR}/missing-version.toml" <<'EOF'
[staging.deploy.parameters]
capabilities = "CAPABILITY_IAM"
EOF
expect_fail "required version missing" \
  "${WORKDIR}/missing-version.toml" "staging" "false" \
  "missing required key 'version'"

cat > "${WORKDIR}/bad-parameters.toml" <<'EOF'
version = 0.1

[staging.deploy]
parameters = "not-a-table"
EOF
expect_fail "invalid parameters on the deploy flow" \
  "${WORKDIR}/bad-parameters.toml" "staging" "false" \
  "[staging.deploy.parameters] must be a table"
expect_ok "deploy parameters are not required on delete" \
  "${WORKDIR}/bad-parameters.toml" "staging" "true"

if [[ "$(id -u)" -eq 0 ]]; then
  echo "skip: unreadable file (euid 0)"
else
  printf 'version = 0.1\n\n[staging.deploy.parameters]\n' > "${WORKDIR}/unreadable.toml"
  chmod 000 "${WORKDIR}/unreadable.toml"
  expect_fail "unreadable file" \
    "${WORKDIR}/unreadable.toml" "staging" "false" \
    "SAM config file not readable: ${WORKDIR}/unreadable.toml"
  chmod 644 "${WORKDIR}/unreadable.toml"
fi

# The pipe must pass the same SAM_CONFIG_FILE and stop before build/package/deploy/delete.
HARNESS="$(mktemp -d)"
mkdir -p "${HARNESS}/home/.nvm" "${HARNESS}/bin" "${HARNESS}/clone" "${HARNESS}/pipe"
printf ':\n' > "${HARNESS}/home/.nvm/nvm.sh"
cat > "${HARNESS}/pipe/common.sh" <<'EOF'
info() { echo "INFO: $*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }
success() { echo "SUCCESS: $*"; }
run() {
  "$@"
  status=$?
  return 0
}
EOF
cp "${PIPE_DIR}/pipe.sh" "${PIPE_DIR}/validate_samconfig.py" "${HARNESS}/pipe/"
cp -R "${PIPE_DIR}/vendor" "${HARNESS}/pipe/vendor"

SAM_ARGS_LOG="${HARNESS}/sam-args.log"
touch "${SAM_ARGS_LOG}"
cat > "${HARNESS}/bin/aws" <<'EOF'
#!/bin/bash
if [[ "${1:-}" == "sts" && "${2:-}" == "assume-role" ]]; then
  printf 'AKIAtest secret token\n'
fi
exit 0
EOF
cat > "${HARNESS}/bin/sam" <<'EOF'
#!/bin/bash
printf '%s\n' "$*" >> "${SAM_ARGS_LOG}"
if [[ "${1:-}" == "--version" ]]; then
  echo "SAM CLI, version 1.169.0"
fi
exit 0
EOF
chmod +x "${HARNESS}/bin/aws" "${HARNESS}/bin/sam"

run_pipe() {
  local config_file="$1"
  local delete_flag="$2"
  local status=0
  : > "${SAM_ARGS_LOG}"
  set +e
  HOME="${HARNESS}/home" \
  PATH="${HARNESS}/bin:${PATH}" \
  SAM_ARGS_LOG="${SAM_ARGS_LOG}" \
  BITBUCKET_CLONE_DIR="${HARNESS}/clone" \
  BITBUCKET_DEPLOYMENT_ENVIRONMENT="staging" \
  SAM_TEMPLATE="template.yaml" \
  PIPELINE_EXECUTION_ROLE="arn:aws:iam::000000000000:role/pipe" \
  CF_STACK_NAME="stack" \
  ARTIFACTS_BUCKET="bucket" \
  CF_EXECUTION_ROLE="arn:aws:iam::000000000000:role/cf" \
  SAM_CONFIG_FILE="${config_file}" \
  ARTIFACTS_BUCKET_PREFIX="qa/repo/stack" \
  PIPELINE_USER_ACCESS_KEY_ID="AKIAtest" \
  PIPELINE_USER_SECRET_ACCESS_KEY="secret" \
  AWS_REGION="us-east-1" \
  DELETE="${delete_flag}" \
  bash "${HARNESS}/pipe/pipe.sh" > "${HARNESS}/pipe.out" 2> "${HARNESS}/pipe.err"
  status=$?
  set -e
  echo "${status}"
}

cp "${WORKDIR}/pipeline-custom.toml" "${HARNESS}/clone/pipeline-custom.toml"
pipe_status=$(run_pipe "pipeline-custom.toml" "false")
if [[ "${pipe_status}" -ne 0 ]]; then
  fail_case "pipe with valid toml (exit ${pipe_status}): $(cat "${HARNESS}/pipe.err")"
else
  sam_calls=$(grep -E '^(build|package|deploy) ' "${SAM_ARGS_LOG}" || true)
  if [[ -z "${sam_calls}" ]]; then
    fail_case "pipe did not invoke sam build/package/deploy"
  elif grep -E '^(build|package|deploy) ' "${SAM_ARGS_LOG}" | grep -qv -- '--config-file pipeline-custom.toml'; then
    fail_case "sam did not receive the same --config-file: $(cat "${SAM_ARGS_LOG}")"
  elif grep -E '^(build|package|deploy) ' "${SAM_ARGS_LOG}" | grep -q 'samconfig.toml'; then
    fail_case "sam used a config file other than the parameter"
  else
    pass "the same SAM_CONFIG_FILE is passed to sam build/package/deploy"
  fi
fi

printf 'version = [\n' > "${HARNESS}/clone/pipeline-custom.toml"
pipe_status=$(run_pipe "pipeline-custom.toml" "false")
if [[ "${pipe_status}" -eq 0 ]]; then
  fail_case "pipe with invalid toml exited 0"
elif grep -E '^(build|package|deploy|delete) ' "${SAM_ARGS_LOG}" >/dev/null; then
  fail_case "pipe invoked sam after validation failed: $(cat "${SAM_ARGS_LOG}")"
else
  pass "validation failure stops the pipe before deploy (exit ${pipe_status})"
fi

rm -rf "${HARNESS}"

if [[ "${failures}" -ne 0 ]]; then
  echo "${failures} case(s) failed" >&2
  exit 1
fi

echo "samconfig validation: all cases passed"
