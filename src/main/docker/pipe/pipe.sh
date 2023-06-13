#!/bin/bash
#
source ~/.nvm/nvm.sh 
source "$(dirname "$0")/common.sh"

info "Enviroment variables setup..."

# Required parameters

export BITBUCKET_CLONE_DIR=${BITBUCKET_CLONE_DIR:?'BITBUCKET_CLONE_DIR variable missing.'}
export BITBUCKET_DEPLOYMENT_ENVIRONMENT=${BITBUCKET_DEPLOYMENT_ENVIRONMENT:?'BITBUCKET_DEPLOYMENT_ENVIRONMENT variable is missing'}

export SAM_TEMPLATE=${SAM_TEMPLATE:?'SAM_TEMPLATE variable missing.'}
export PIPELINE_EXECUTION_ROLE=${PIPELINE_EXECUTION_ROLE:?'PIPELINE_EXECUTION_ROLE variable missing.'}
export CF_STACK_NAME=${CF_STACK_NAME:?'CF_STACK_NAME variable is missing'}
export ARTIFACTS_BUCKET=${ARTIFACTS_BUCKET:?'ARTIFACTS_BUCKET variable is missing'}
export CF_EXECUTION_ROLE=${CF_EXECUTION_ROLE:?'CF_EXECUTION_ROLE variable is missing'}
export SAM_CONFIG_FILE=${SAM_CONFIG_FILE:?'SAM_CONFIG_FILE is missing'} #samconfig.toml
export ARTIFACTS_BUCKET_PREFIX=${ARTIFACTS_BUCKET_PREFIX:?'ARTIFACTS_BUCKET_PREFIX is missing'}
export OUTPUT_TEMPLATE_FILE="packaged-template.yaml"

# Disables SAM TELEMETRY
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

# HANDLE FAIL_ON_EMPTY_CHANGESET PARAMETER
export FAIL_ON_EMPTY_CHANGESET=${FAIL_ON_EMPTY_CHANGESET:="false"}
if [[ "${FAIL_ON_EMPTY_CHANGESET}" == "true" ]]; then
    info "Running with --fail-on-empty-changeset"
    export PARAM_FAIL_ON_EMPTY_CHANGESET="--fail-on-empty-changeset"
else
    info "Running with --no-fail-on-empty-changeset"
    export PARAM_FAIL_ON_EMPTY_CHANGESET="--no-fail-on-empty-changeset"
fi

# HANDLE SKIP_CHANGESET_EXECUTION PARAMETER
export SKIP_CHANGESET_EXECUTION=${SKIP_CHANGESET_EXECUTION:="false"}
if [[ "${SKIP_CHANGESET_EXECUTION}" == "true" ]]; then
    export NO_EXECUTE_CHANGESET="--no-execute-changeset"
else
    export NO_EXECUTE_CHANGESET=""
fi

# HANDLE AWS CREDENTIALS
export BITBUCKET_STEP_OIDC_TOKEN=${BITBUCKET_STEP_OIDC_TOKEN:='false'}
if [[ "${BITBUCKET_STEP_OIDC_TOKEN}" != "false" ]]
then
    info "Using OIDC authentication for aws ..."
    # unset env variables to prevent aws client general auth
    unset AWS_ACCESS_KEY_ID
    unset AWS_SECRET_ACCESS_KEY
    unset AWS_SESSION_TOKEN
    # setup token file
    export WEB_IDENTITY_TOKEN_FILE="web-identity-token.txt"
    echo "${BITBUCKET_STEP_OIDC_TOKEN}" > ${WEB_IDENTITY_TOKEN_FILE}
    # setup environment variables
    export AWS_WEB_IDENTITY_TOKEN_FILE=$(pwd)/${WEB_IDENTITY_TOKEN_FILE}
    export AWS_ROLE_SESSION_NAME=${ROLE_SESSION_NAME:="BitbucketPipeline"}
    export AWS_ROLE_ARN="${PIPELINE_EXECUTION_ROLE}"
else
    info "Using IAM authentication for aws ..."
    export AWS_ACCESS_KEY_ID=${PIPELINE_USER_ACCESS_KEY_ID:?'PIPELINE_USER_ACCESS_KEY_ID variable missing.'}
    export AWS_SECRET_ACCESS_KEY=${PIPELINE_USER_SECRET_ACCESS_KEY:?'PIPELINE_USER_SECRET_ACCESS_KEY variable missing.'}
    export AWS_REGION=${AWS_REGION:?'AWS_REGION variable is missing'}
    aws sts get-caller-identity > aws-identity.json
fi

# Check for valid credentials
aws sts get-caller-identity > aws-identity.json
if [[ $? -ne 0 ]]
then
    fail "Invalid credentials given."
    exit -1
fi
echo "Running sam commands with the following identity:"
cat aws-identity.json

export DELETE=${DELETE:="false"}

run sam --version

info "BITBUCKET_CLONE_DIR = ${BITBUCKET_CLONE_DIR}"
cd $BITBUCKET_CLONE_DIR

if [[ "${DELETE}" != "true" ]]; then
    info "Running sam build command..."
    run sam build ${PARAM_DEBUG} --template $SAM_TEMPLATE --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}"
fi

if [[ "${BITBUCKET_STEP_OIDC_TOKEN}" == "false" ]]
then
    # Only needed when using IAM auth
    info "Assuming pipeline execution role..."
    cred=$(aws sts assume-role --role-arn "$PIPELINE_EXECUTION_ROLE" --role-session-name "testing-stage-packaging" --query '[Credentials.AccessKeyId,Credentials.SecretAccessKey,Credentials.SessionToken]' --output text)
    export AWS_ACCESS_KEY_ID=$(echo "$cred" | awk '{ print $1 }')
    export AWS_SECRET_ACCESS_KEY=$(echo "$cred" | awk '{ print $2 }')
    export AWS_SESSION_TOKEN=$(echo "$cred" | awk '{ print $3 }')
fi

if [[ "${DELETE}" != "true" ]]; then
    info "Running sam package command..."
    run sam package ${PARAM_DEBUG} --s3-bucket "${ARTIFACTS_BUCKET}" --s3-prefix "${ARTIFACTS_BUCKET_PREFIX}" --region "${AWS_REGION}" --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}" --output-template-file ${OUTPUT_TEMPLATE_FILE}

    info "Running sam deploy command..."
    run sam deploy  ${PARAM_DEBUG} --s3-bucket "${ARTIFACTS_BUCKET}" --s3-prefix "${ARTIFACTS_BUCKET_PREFIX}" --region "${AWS_REGION}" --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}"             --template ${OUTPUT_TEMPLATE_FILE} --stack-name ${CF_STACK_NAME} --role-arn "${CF_EXECUTION_ROLE}" ${CAPABILITY_OPTION} ${PARAM_FAIL_ON_EMPTY_CHANGESET} ${NO_EXECUTE_CHANGESET}
fi

if [[ "${DELETE}" == "true" ]]; then
    info "Running sam delete command..."
    run sam delete  ${PARAM_DEBUG} --s3-bucket "${ARTIFACTS_BUCKET}" --s3-prefix "${ARTIFACTS_BUCKET_PREFIX}" --region "${AWS_REGION}" --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}"                                                --stack-name ${CF_STACK_NAME} --no-prompts
fi

if [[ "${status}" == "0" ]]; then
  success "Success!"
else
  fail "Error!"
fi