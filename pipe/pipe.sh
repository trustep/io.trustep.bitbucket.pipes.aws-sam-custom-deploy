#!/bin/bash
#
# This pipe is an example to show how easy is to create pipes for Bitbucket Pipelines.
#

source "$(dirname "$0")/common.sh"

info "Enviroment variables setup..."

# Required parameters

export BITBUCKET_CLONE_DIR=${BITBUCKET_CLONE_DIR:?'BITBUCKET_CLONE_DIR variable missing.'}
export BITBUCKET_REPO_SLUG=${BITBUCKET_REPO_SLUG:?'BITBUCKET_REPO_SLUG variable is missing'}
export BITBUCKET_DEPLOYMENT_ENVIRONMENT=${BITBUCKET_DEPLOYMENT_ENVIRONMENT:?'BITBUCKET_DEPLOYMENT_ENVIRONMENT variable is missing'}

export AWS_ACCESS_KEY_ID=${PIPELINE_USER_ACCESS_KEY_ID:?'PIPELINE_USER_ACCESS_KEY_ID variable missing.'}
export AWS_SECRET_ACCESS_KEY=${PIPELINE_USER_SECRET_ACCESS_KEY:?'PIPELINE_USER_SECRET_ACCESS_KEY variable missing.'}
export AWS_REGION=${AWS_REGION:?'AWS_REGION variable is missing'}

export SAM_TEMPLATE=${SAM_TEMPLATE:?'SAM_TEMPLATE variable missing.'}
export OUTPUT_TEMPLATE_FILE=${OUTPUT_TEMPLATE_FILE:?'OUTPUT_TEMPLATE_FILE variable missing.'} #packaged-template.yaml
export PIPELINE_EXECUTION_ROLE=${PIPELINE_EXECUTION_ROLE:?'PIPELINE_EXECUTION_ROLE variable missing.'}
export CF_STACK_NAME=${CF_STACK_NAME:?'CF_STACK_NAME variable is missing'}
export ARTIFACTS_BUCKET=${ARTIFACTS_BUCKET:?'ARTIFACTS_BUCKET variable is missing'}
export CLOUDFORMATION_EXECUTION_ROLE=${CLOUDFORMATION_EXECUTION_ROLE:?'CLOUDFORMATION_EXECUTION_ROLE variable is missing'}
export SAM_CONFIG_FILE=${SAM_CONFIG_FILE:?'SAM_CONFIG_FILE is missing'} #samconfig.toml
export ARTIFACTS_BUCKET_PREFIX="${BITBUCKET_DEPLOYMENT_ENVIRONMENT}/${BITBUCKET_REPO_SLUG}/${CF_STACK_NAME}"
export SAM_CLI_TELEMETRY=0

# HANDLE CAPABILITIES PARAMETER
export CAPABILITIES=${CAPABILITIES:='NOCAPABILITIES'}
if [[ "${CAPABILITIES}" == "NOCAPABILITIES" ]]; then
    info "Running without the --capabilities option"
    export CAPABILITY_OPTION=""
else
    export CAPABILITY_OPTION="--capabilities ${CAPABILITIES}"
    info "Running with ${CAPABILITY_OPTION}"
fi

# HANDLE DEBUG PARAMETER
export DEBUG=${DEBUG:="false"}
if [[ "${DEBUG}" == "true" ]]; then
    info "Running with debug enabled"
    export PARAM_DEBUG="--debug"
else
    info "Running with debug disabled"
    export PARAM_DEBUG=""
fi


info "BITBUCKET_CLONE_DIR = ${BITBUCKET_CLONE_DIR}"
cd $BITBUCKET_CLONE_DIR

info "Running sam build command..."
run sam build ${PARAM_DEBUG} --template $SAM_TEMPLATE --use-container --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}"

info "Assuming pipeline execution role..."
cred=$(aws sts assume-role --role-arn "$PIPELINE_EXECUTION_ROLE" --role-session-name "testing-stage-packaging" --query '[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken]' --output text)
export AWS_ACCESS_KEY_ID=$(echo "$cred" | awk '{ print $1 }')
export AWS_SECRET_ACCESS_KEY=$(echo "$cred" | awk '{ print $2 }')
export AWS_SESSION_TOKEN=$(echo "$cred" | awk '{ print $3 }')

info "Running sam package command..."
run sam package ${PARAM_DEBUG} --s3-bucket "${ARTIFACTS_BUCKET}" --s3-prefix "${ARTIFACTS_BUCKET_PREFIX}" --region "${AWS_REGION}" --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}" --output-template-file ${OUTPUT_TEMPLATE_FILE}

info "Running sam deploy command..."
run sam deploy  ${PARAM_DEBUG} --s3-bucket "${ARTIFACTS_BUCKET}" --s3-prefix "${ARTIFACTS_BUCKET_PREFIX}" --region "${AWS_REGION}" --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}"             --template ${OUTPUT_TEMPLATE_FILE} --stack-name ${CF_STACK_NAME} --role-arn "${CLOUDFORMATION_EXECUTION_ROLE}" ${CAPABILITY_OPTION} --no-fail-on-empty-changeset

if [[ "${status}" == "0" ]]; then
  success "Success!"
else
  fail "Error!"
fi