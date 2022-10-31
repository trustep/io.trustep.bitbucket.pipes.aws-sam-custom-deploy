# Bitbucket Pipelines Pipe: AWS SAM Custom Deploy

Deploys a AWS SAM application with custom parameters.

This pipe is uses public.ecr.aws/sam/build-provided public image as base to issue calls to the sam commands build, package and deploy using a set of custom parameters.

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
```

## Variables

| Variable                         | Required | Default Value                                                               | Usage |
| :------------------------------- | :------: | :-------------------------------------------------------------------------- | ----- |
| BITBUCKET_CLONE_DIR              | Yes      | ${BITBUCKET_CLONE_DIR}                                                      | The path where project has been cloned. The default value sets it to the bitbucket pipelines variable. |
| BITBUCKET_DEPLOYMENT_ENVIRONMENT | Yes      | ${BITBUCKET_DEPLOYMENT_ENVIRONMENT}                                         | The bitbucket deployment environment being used. This value will be used as --config-env parameter and must match the corresponding section within samconfig.toml. This is set set by bitbucket pipelines engine if you use the deployment option within your step. |
| AWS_REGION                       | Yes      | ${AWS_REGION}                                                               | The AWS Region where the stack should be deployed |
| PIPELINE_USER_ACCESS_KEY_ID      | Yes      | ${PIPELINE_USER_ACCESS_KEY_ID}                                              | AWS Credentials used to by pipeline execution. This can be created by sam pipeline bootstrap command or you can use other credentials with permissions to deploy the cloudformation stack. |
| PIPELINE_USER_SECRET_ACCESS_KEY  | Yes      | ${PIPELINE_USER_SECRET_ACCESS_KEY}                                          | AWS Credentials used to by pipeline execution. This can be created by sam pipeline bootstrap command or you can use other credentials with permissions to deploy the cloudformation stack. |
| PIPELINE_EXECUTION_ROLE          | Yes      | ${PIPELINE_EXECUTION_ROLE}                                                  | ARN of the role to be used within pipeline execution. This role is created by sam pipeline bootstrap command. |
| SAM_TEMPLATE                     | Yes      | template.yaml                                                               | Name of the sam template file. Tipically set to template.yaml |
| SAM_CONFIG_FILE                  | Yes      | samconfig.toml                                                              | Name of the sam config file. Tipically set to samconfig.toml |
| CF_STACK_NAME                    | Yes      | ${CF_STACK_NAME}                                                            | The name of the cloudformation stack to be deployed from this pipe execution |
| CF_EXECUTION_ROLE                | Yes      | ${CF_EXECUTION_ROLE}                                                        | ARN of the role to be used within cloudformation execution. This role is created by sam pipeline bootstrap command. |
| ARTIFACTS_BUCKET                 | Yes      | ${ARTIFACTS_BUCKET}                                                         | Name of the bucket where artifacts will be uploaded for deployment |
| ARTIFACTS_BUCKET_PREFIX          | Yes      | ${BITBUCKET_DEPLOYMENT_ENVIRONMENT}/${BITBUCKET_REPO_SLUG}/${CF_STACK_NAME} | Passed as argument to package and deploy commands to allow organizing deployments within the artifact bucket. |
| CAPABILITIES                     | No       | 'NOCAPABILITIES'                                                            | Which IAM capabilities must be enabled: CAPABILITY_IAM, CAPABILITY_NAMED_IAM or NOCAPABILITIES (the default) are the available values |
| DEBUG                            | No       | 'false'                                                                     | Turn on extra debug information. | 

The default values that references environment variables, exception made to those starting as "BITBUCKET_*", should be set either within bitbucket environment variables or directly withing the pipeline definition.

## Prerequisites

This pipe was writen with the idea that you had ran sam pipeline bootstrap command anytime before setting up your pipeline. Almost all variables can be derived directly from the outputs generated by that command.

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
If you'd like help with this pipe, or you have an issue or feature request, let us know on our github repository.

If you're reporting an issue, please include:

* the version of the pipe
* relevant logs and error messages
* steps to reproduce

## License
Copyright (c) 2022 Trustep.
Apache 2.0 licensed, see [LICENSE](LICENSE) file.
