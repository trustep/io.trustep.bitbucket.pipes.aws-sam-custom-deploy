# Bitbucket Pipelines Pipe: AWS SAM Custom Deploy by TruStep

A BitBucket Pipe based on public.ecr.aws/sam/build-provided image to allow customized AWS SAM deploys. 

Allows deployments of AWS SAM applications with various custom parameters. 

This pipe uses public.ecr.aws/sam/build-provided public image as base to issue calls to the sam commands build, package, deploy and delete using a set of custom parameters.

You can use the default deployment mode or the delete mode.

The deployment mode will run sam build, sam package and sam deploy commands.

The delete mode will run only sam delete command.

## YAML Definition

Add the following snippet to the script section of your `bitbucket-pipelines.yml` file:

```yaml
- pipe: trustep/aws-sam-custom-deploy:1.0.0
  variables:
    BITBUCKET_CLONE_DIR: '<string>'
    BITBUCKET_DEPLOYMENT_ENVIRONMENT: '<string>'
    AWS_REGION: '<string>'
    PIPELINE_USER_ACCESS_KEY_ID: '<string>'
    PIPELINE_USER_SECRET_ACCESS_KEY: '<string>'
    PIPELINE_EXECUTION_ROLE: '<ARN string>'
    SAM_TEMPLATE: '<string>'
    SAM_CONFIG_FILE: '<string>'
    CF_STACK_NAME: '<string>'
    CF_EXECUTION_ROLE: '<ARN string>'
    ARTIFACTS_BUCKET: '<string>'
    ARTIFACTS_BUCKET_PREFIX: '<string>'
    CAPABILITIES: '<CAPABILITY_IAM|CAPABILITY_NAMED_IAM|NOCAPABILITIES>'
    DEBUG: '<true|false>'
    DELETE: '<true|false>'
    FAIL_ON_EMPTY_CHANGESET: '<true|false>'
    SKIP_CHANGESET_EXECUTION: '<true|false>'
```

## Variables

| Variable                         | Required | Default Value                                                               | Usage |
| :------------------------------- | :------: | :-------------------------------------------------------------------------- | ----- |
| BITBUCKET_CLONE_DIR              | Yes      | ${BITBUCKET_CLONE_DIR}                                                      | The path where project has been cloned. The default value sets it to the bitbucket pipelines variable. |
| BITBUCKET_DEPLOYMENT_ENVIRONMENT | Yes      | ${BITBUCKET_DEPLOYMENT_ENVIRONMENT}                                         | The bitbucket deployment environment being used. This value will be used as --config-env parameter and must match the corresponding section within samconfig.toml. This is set set by bitbucket pipelines engine if you use the deployment option within your step. |
| AWS_REGION                       | Yes      | ${AWS_REGION}                                                               | The AWS Region where the stack should be deployed |
| PIPELINE_USER_ACCESS_KEY_ID      | No       | ${PIPELINE_USER_ACCESS_KEY_ID}                                              | AWS Credentials used to by pipeline execution. This can be created by sam pipeline bootstrap command or you can use other credentials with permissions to deploy the cloudformation stack. |
| PIPELINE_USER_SECRET_ACCESS_KEY  | No       | ${PIPELINE_USER_SECRET_ACCESS_KEY}                                          | AWS Credentials used to by pipeline execution. This can be created by sam pipeline bootstrap command or you can use other credentials with permissions to deploy the cloudformation stack. |
| PIPELINE_EXECUTION_ROLE          | Yes      | ${PIPELINE_EXECUTION_ROLE}                                                  | ARN of the role to be used within pipeline execution. This role is created by sam pipeline bootstrap command. |
| SAM_TEMPLATE                     | Yes      | template.yaml                                                               | Name of the sam template file. Tipically set to template.yaml |
| SAM_CONFIG_FILE                  | Yes      | samconfig.toml                                                              | Name of the sam config file. Tipically set to samconfig.toml |
| CF_STACK_NAME                    | Yes      | ${CF_STACK_NAME}                                                            | The name of the cloudformation stack to be deployed from this pipe execution |
| CF_EXECUTION_ROLE                | Yes      | ${CF_EXECUTION_ROLE}                                                        | ARN of the role to be used within cloudformation execution. This role is created by sam pipeline bootstrap command. |
| ARTIFACTS_BUCKET                 | Yes      | ${ARTIFACTS_BUCKET}                                                         | Name of the bucket where artifacts will be uploaded for deployment |
| ARTIFACTS_BUCKET_PREFIX          | Yes      | ${BITBUCKET_DEPLOYMENT_ENVIRONMENT}/${BITBUCKET_REPO_SLUG}/${CF_STACK_NAME} | Passed as argument to package and deploy commands to allow organizing deployments within the artifact bucket. |
| CAPABILITIES                     | No       | NOCAPABILITIES                                                              | Which IAM capabilities must be enabled: CAPABILITY_IAM, CAPABILITY_NAMED_IAM or NOCAPABILITIES (the default) are the available values |
| DEBUG                            | No       | false                                                                       | Turn on extra debug information. | 
| DELETE                           | No       | false                                                                       | When enabled, runs the sam delete command instead of regular build/package/deploy commands. | 
| FAIL_ON_EMPTY_CHANGESET          | No       | false                                                                       | When enabled, adds to the sam command the option --fail-on-empty-changeset. Only applies to Deployment mode. | 
| SKIP_CHANGESET_EXECUTION         | No       | false                                                                       | When enabled, adds to the sam command the option --no-execute-changeset. Only applies to Deployment mode. | 
| ROLE_SESSION_NAME                | No       | BitbucketPipeline                                                           | When using OIDC authentication, this indicates the role session name asigned to your session. | 

The default values that references environment variables, exception made to those starting as "BITBUCKET_*", should be set either within bitbucket environment variables or directly withing the pipeline definition.
Note that is mandatory to setup one of two authentication schemes: IAM or OIDC. If you don't setup one of them, execution will fail.

## Details

This pipe was developed to allow using specific aws sam command line options that are not available in the AWS SAM default pipe.
There are two distinct modes you can use: deploy (default) and delete.
For now, the parameters you must pass on both modes are the same, even if some is not used in delete mode (maybe a future enhancement??)

### Deployment mode

In this mode, the default, the pipe executes all three commands in sequence:

1. sam build

```bash
sam build ${PARAM_DEBUG} --template $SAM_TEMPLATE --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}"
```

2. sam package

```bash
sam package ${PARAM_DEBUG} --s3-bucket "${ARTIFACTS_BUCKET}" --s3-prefix "${ARTIFACTS_BUCKET_PREFIX}" --region "${AWS_REGION}" --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}" --output-template-file ${OUTPUT_TEMPLATE_FILE}
```

3. sam deploy

```bash
run sam deploy ${PARAM_DEBUG} --s3-bucket "${ARTIFACTS_BUCKET}" --s3-prefix "${ARTIFACTS_BUCKET_PREFIX}" --region "${AWS_REGION}" --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}" --template ${OUTPUT_TEMPLATE_FILE} --stack-name ${CF_STACK_NAME} --role-arn "${CF_EXECUTION_ROLE}" ${CAPABILITY_OPTION} --no-fail-on-empty-changeset
```

You can customize which aws sam options to use through parameters passed to the pipe.

### Delete mode

To enable the delete mode you must pass DELETE="true" when invoking the pipe.
The command executed is:

1. sam delete

```bash
    run sam delete  ${PARAM_DEBUG} --s3-bucket "${ARTIFACTS_BUCKET}" --s3-prefix "${ARTIFACTS_BUCKET_PREFIX}" --region "${AWS_REGION}" --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}" --stack-name ${CF_STACK_NAME} --no-prompts
```

### Authentication

There is two supported authentication schemes: IAM and OIDC.

* To use IAM credentials, you just have to setup PIPELINE_USER_ACCESS_KEY_ID and PIPELINE_USER_SECRET_ACCESS_KEY with desired credentials.

* To use OIDC authentication you need to:

1. Configure Bitbucket Pipelines as a Web Identity Provider on AWS.
2. Setup option **oidc: true** in the pipeline step you want to run the pipe. This will create the environment variable BITBUCKET_STEP_OIDC_TOKEN automatically.

More details on how to setup OIDC authentication in AWS can be found at [this guide](https://support.atlassian.com/bitbucket-cloud/docs/deploy-on-aws-using-bitbucket-pipelines-openid-connect/).

OIDC authentication take precedence over IAM authentication. That means if you setup both schemes, OIDC will be preferred.
Note that if you use OIDC authentication, PIPELINE_EXECUTION_ROLE will be assumed using the Web Identity Token given by AWS to Bitbucket Pipelines session.
You can also change default role session name using ROLE_SESSION_NAME parameter.

## Prerequisites

We strongly recommend that you had ran sam pipeline bootstrap command anytime before setting up your pipeline. 
Almost all variables can be derived directly from the outputs generated by that command.
But you can setup your own users, roles and IAM permissions, considering that those roles can deploy aws cloudformation/sam applications and upload to the corresponding S3 buckets.

## Examples

Basic example:
    
```yaml
script:
  - pipe: trustep/aws-sam-custom-deploy:1.0.0
    variables:
      AWS_REGION: 'us-east-1'
      PIPELINE_USER_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID # Credentials generated by sam pipeline bootstrap and setup as a secret Environment Variable
      PIPELINE_USER_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY # Credentials generated by sam pipeline bootstrap and setup as a secret Environment Variable
      PIPELINE_EXECUTION_ROLE: 'arn:aws:iam::123456789012:role/aws-sam-cli-managed-Test-PipelineExecutionRole-5KF51ETFXFH9'
      SAM_CONFIG_FILE: 'samconfig.toml'
      CF_STACK_NAME: 'my-stack-name'
      CF_EXECUTION_ROLE: 'arn:aws:iam::123456789012:role/aws-sam-cli-managed-Test-CloudFormationExecutionRole-UJHY67GT5GE4'
      ARTIFACTS_BUCKET: 'my-artifacts-buckect-name'
```

## Support
If you'd like help with this pipe, or you have an issue or feature request, let us know on our [github repository](https://github.com/trustep/io.trustep.bitbucket.pipes.aws-sam-custom-deploy).

If you're reporting an issue, please include:

* the version of the pipe
* relevant logs and error messages
* steps to reproduce

## License
Copyright (c) 2022-2023 Trustep.
Apache 2.0 licensed, see [LICENSE](LICENSE) file.
