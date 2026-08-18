# Bitbucket Pipelines Pipe: AWS SAM Custom Deploy by TruStep

A Bitbucket Pipe based on `public.ecr.aws/sam/build-provided.al2023` that runs customized AWS SAM CLI
`build`, `package`, `deploy`, and `delete` flows from Bitbucket Pipelines.

Published images and tags:
[Docker Hub — trustep/aws-sam-custom-deploy](https://hub.docker.com/r/trustep/aws-sam-custom-deploy/tags).

## Contents

* [Scope](#scope)
* [Compared to the official AWS SAM pipe](#compared-to-the-official-aws-sam-pipe)
* [Versioning (consumers)](#versioning-consumers)
* [Image variants](#image-variants)
* [Prerequisites](#prerequisites)
* [Quick start](#quick-start)
* [samconfig contract](#samconfig-contract)
* [Roles and execution flow](#roles-and-execution-flow)
* [YAML definition](#yaml-definition)
* [Variables](#variables)
* [Details](#details)
* [Examples](#examples)
* [Troubleshooting](#troubleshooting)
* [Support](#support)
* [License](#license)

## Scope

**This pipe does:**

* Run `sam build`, `sam package`, and `sam deploy` in sequence (deployment mode).
* Run `sam delete` when `DELETE=true`.
* Pass selected SAM CLI flags controlled by pipe variables (`CAPABILITIES`, empty-changeset behavior,
  skip changeset execution, debug).
* Authenticate with IAM access keys or Bitbucket OIDC (OIDC takes precedence when both are present).
* Publish multiple image variants (custom + selected Node/Python SAM build bases) from one catalog.

**This pipe does not:**

* Expose arbitrary SAM CLI flags beyond the variables listed below.
* Replace `samconfig.toml` as the source of environment-specific SAM settings.
* Support `sam sync`, guided deploy, multi-stack orchestration, or a custom build-image override.
* Pass `sam build --use-container` or provide a Docker daemon for containerized builds.
* Provide a general-purpose AWS CLI wrapper.

Pick the image tag that matches your Lambda runtime toolchain (see [Image variants](#image-variants)).
Apps that require `sam build --use-container` or toolchains not present in the chosen variant are out
of scope for this pipe as shipped.

## Compared to the official AWS SAM pipe

Use this pipe when you need Bitbucket-friendly control over options such as:

* `--fail-on-empty-changeset` / `--no-fail-on-empty-changeset`
* `--no-execute-changeset` (create the changeset without applying it)
* Explicit artifact bucket prefix layout
* Deploy vs delete in the same pipe image
* IAM access keys with `sts:AssumeRole` into `PIPELINE_EXECUTION_ROLE`, or OIDC web identity for that role

If you only need a minimal SAM deploy and the official Atlassian/AWS pipe already covers your flags,
that pipe may be enough. This project exists for the customization gaps above.

## Versioning (consumers)

Pipe image tags mirror the AWS SAM CLI version embedded in the chosen SAM build base image.

* Current target SAM CLI version: **1.165.0**
* Prefer a pinned `x.y.z` (optionally with a runtime suffix) when you need a reproducible SAM CLI contract.
* `latest` / `latest-<runtime>` are floating tags published from `main`.
* Browse published tags on
  [Docker Hub](https://hub.docker.com/r/trustep/aws-sam-custom-deploy/tags).

| Tag | Behavior |
| :-- | :------- |
| `trustep/aws-sam-custom-deploy:latest` | Floating default (custom) image from `main`. |
| `trustep/aws-sam-custom-deploy:x.y.z` | Immutable default (custom) release. |
| `trustep/aws-sam-custom-deploy:latest-<runtime>` | Floating runtime-specific image from `main`. |
| `trustep/aws-sam-custom-deploy:x.y.z-<runtime>` | Immutable runtime-specific release. |

**Recommendation:** prefer `:latest` (or `:latest-<runtime>`) when you want to stay aligned with the
newest SAM CLI and pipe improvements with minimal maintenance.

The right choice still depends on each project. Prefer a specific `x.y.z` tag when you need reproducible
pipelines, stricter change control, or deliberate SAM CLI upgrades (for example regulated environments,
long-lived release trains, or teams that validate tooling upgrades before production).

## Image variants

The catalog is static in [`src/main/docker/variants.json`](src/main/docker/variants.json). Each entry is
built and published on release/`main`.

| Suffix | Base image | Notes |
| :----- | :--------- | :---- |
| *(none)* | `public.ecr.aws/sam/build-provided.al2023` | **Default / compatibility.** Adds NVM + Node.js 22. Tags: `latest`, `1.165.0`. |
| `-nodejs24.x` | `public.ecr.aws/sam/build-nodejs24.x` | Official Node 24 build image. Tags: `latest-nodejs24.x`, `1.165.0-nodejs24.x`. |
| `-nodejs22.x` | `public.ecr.aws/sam/build-nodejs22.x` | Official Node 22 build image. Tags: `latest-nodejs22.x`, `1.165.0-nodejs22.x`. |
| `-python3.14` | `public.ecr.aws/sam/build-python3.14` | Official Python 3.14 build image. |
| `-python3.13` | `public.ecr.aws/sam/build-python3.13` | Official Python 3.13 build image. |
| `-python3.12` | `public.ecr.aws/sam/build-python3.12` | Official Python 3.12 build image. |

Example:

```yaml
- pipe: trustep/aws-sam-custom-deploy:latest-python3.13
```

To add or remove a supported runtime, edit `variants.json` (no dynamic discovery).

### Maintainer notes

To advance the target SAM version: update `SAM_TARGET_VERSION` in
`.github/workflows/pipeline.yaml`, the `SAM_CLI_VERSION` default in `src/main/docker/Dockerfile`,
`image` in `src/main/docker/pipe.yml`, and this README; then publish via a `release*` branch.
All variants in `variants.json` are rebuilt against that SAM version.

`src/main/docker/pipe.yml` pins a concrete image tag for the pipe metadata packaged inside the image
(currently the target `x.y.z` without runtime suffix). Consumers choose `latest`, `x.y.z`, or a
suffixed tag in the `pipe:` line themselves.

## Prerequisites

Before using the pipe, ensure:

1. An AWS SAM application in the repository (`template.yaml` / `template.yml` and application code).
2. A `samconfig.toml` (or equivalent) with a config environment whose name matches the Bitbucket
   deployment environment (see [samconfig contract](#samconfig-contract)).
3. An S3 artifacts bucket usable by the pipeline and CloudFormation execution roles.
4. IAM roles suitable for packaging/deploying the stack. **Recommended:** run
   `sam pipeline bootstrap` once — it creates the pipeline user/OIDC trust pieces, the
   **pipeline execution role** (`PIPELINE_EXECUTION_ROLE`), the **CloudFormation execution role**
   (`CF_EXECUTION_ROLE`), and the related permissions (including assume-role trust). You can bring
   your own roles instead, as long as they can package to the artifacts bucket and deploy the stack.
5. Bitbucket repository/deployment variables for secrets and shared settings (`AWS_REGION`, role ARNs,
   bucket name, access keys if using IAM). Prefer mapping Bitbucket variables from the bootstrap
   outputs so you do not hand-wire trust policies.
6. A pipeline step that uses `deployment: <env>` so Bitbucket sets `BITBUCKET_DEPLOYMENT_ENVIRONMENT`
   (unless you pass that variable explicitly).

## Quick start

1. Create or reuse roles and an artifacts bucket (`sam pipeline bootstrap` is the usual path).
2. Add a `samconfig.toml` section named exactly like your Bitbucket deployment environment.
3. Store secrets/variables in Bitbucket (repository or deployment environment).
4. Add a step like the [basic IAM deploy example](#examples).
5. Run the pipeline and confirm `sam --version` in the logs matches the pipe tag you pinned (or the
   SAM CLI paired with `latest`).

## samconfig contract

The pipe always passes:

* `--config-file ${SAM_CONFIG_FILE}` (default `samconfig.toml`)
* `--config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}"`

So if the step uses `deployment: qa`, `samconfig.toml` must define a `qa` environment, for example:

```toml
version = 0.1

[qa.deploy.parameters]
capabilities = "CAPABILITY_IAM"
parameter_overrides = "MyParam=\"value\""
```

**CLI overrides vs samconfig:** arguments the pipe passes on the command line (stack name, region,
artifact bucket/prefix, packaged template path, `--role-arn` on deploy, empty-changeset /
skip-execution flags, and `--debug` when enabled) are set for that run.

`CAPABILITIES` is special:

* If set to anything other than `NOCAPABILITIES`, the pipe adds `--capabilities <value>` on deploy
  with no further validation (typical values: `CAPABILITY_IAM`, `CAPABILITY_NAMED_IAM`).
* If left as `NOCAPABILITIES` (default), the pipe omits `--capabilities`, so any `capabilities` value
  in `samconfig.toml` for that config env can still apply.

Keep environment defaults and parameter overrides in `samconfig.toml`; use pipe variables for the
orchestration controls listed in this README.

Paths such as `SAM_TEMPLATE` and `SAM_CONFIG_FILE` are resolved after `cd ${BITBUCKET_CLONE_DIR}`.

## Roles and execution flow

Authentication is chosen as follows: if `BITBUCKET_STEP_OIDC_TOKEN` is set to any value other than the
literal `false` (the script default when unset), the pipe uses **OIDC**. Otherwise it uses **IAM**.

### IAM path

1. Sets `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` from `PIPELINE_USER_*` and requires `AWS_REGION`.
2. Validates credentials with `sts get-caller-identity`.
3. Prints `sam --version` and `cd` into `BITBUCKET_CLONE_DIR`.
4. **Deployment mode only:** runs `sam build` with the pipeline user credentials.
5. Assumes `PIPELINE_EXECUTION_ROLE` via `sts:AssumeRole` (session name hardcoded as
   `testing-stage-packaging`; `ROLE_SESSION_NAME` is not used on this path).
6. **Deployment mode:** runs `sam package` then `sam deploy` (deploy passes `--role-arn` =
   `CF_EXECUTION_ROLE`).
7. **Delete mode:** skips build/package/deploy; runs `sam delete` under the assumed role.

### OIDC path

1. Clears static AWS keys, writes the web identity token file, and sets `AWS_ROLE_ARN` to
   `PIPELINE_EXECUTION_ROLE` and `AWS_ROLE_SESSION_NAME` from `ROLE_SESSION_NAME` (default
   `BitbucketPipeline`).
2. Validates credentials with `sts get-caller-identity`.
3. Prints `sam --version` and `cd` into `BITBUCKET_CLONE_DIR`.
4. Does **not** call `sts:AssumeRole`.
5. **Deployment mode:** `sam build`, then `sam package`, then `sam deploy` (with
   `--role-arn "${CF_EXECUTION_ROLE}"`).
6. **Delete mode:** `sam delete` only.

| Role / identity | Purpose |
| :-------------- | :------ |
| Pipeline user access keys | IAM path: initial identity for STS and `sam build` |
| OIDC web identity (`BITBUCKET_STEP_OIDC_TOKEN`) | OIDC path: credentials for the whole run via `PIPELINE_EXECUTION_ROLE` |
| `PIPELINE_EXECUTION_ROLE` | IAM: assumed after build for package/deploy/delete. OIDC: web-identity role for the run |
| `CF_EXECUTION_ROLE` | Passed to `sam deploy` as `--role-arn`. Still **required to be set** in delete mode, but not passed to `sam delete` |

## YAML definition

Add the following snippet to the `script` section of your `bitbucket-pipelines.yml` file.
The recommended tag is `latest`; pin an `x.y.z` tag only when your project needs a fixed SAM CLI contract
(see [Versioning](#versioning-consumers)).

```yaml
- pipe: trustep/aws-sam-custom-deploy:latest
  variables:
    BITBUCKET_CLONE_DIR: '<string>'
    BITBUCKET_DEPLOYMENT_ENVIRONMENT: '<string>'
    BITBUCKET_STEP_OIDC_TOKEN: '<string>'
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
    CAPABILITIES: '<CAPABILITY_IAM|CAPABILITY_NAMED_IAM|NOCAPABILITIES|other>'
    DEBUG: '<true|false>'
    DELETE: '<true|false>'
    FAIL_ON_EMPTY_CHANGESET: '<true|false>'
    SKIP_CHANGESET_EXECUTION: '<true|false>'
    ROLE_SESSION_NAME: '<string>'
```

## Variables

| Variable | Required | Default | Usage |
| :------- | :------: | :------ | :---- |
| BITBUCKET_CLONE_DIR | Yes | `${BITBUCKET_CLONE_DIR}` | Clone path. Always validated. Usually provided by Bitbucket Pipelines. |
| BITBUCKET_DEPLOYMENT_ENVIRONMENT | Yes | `${BITBUCKET_DEPLOYMENT_ENVIRONMENT}` | Always validated. Used as `--config-env`. Must match a section in `samconfig.toml`. Set automatically when the step uses `deployment:`. |
| BITBUCKET_REPO_SLUG | No* | `${BITBUCKET_REPO_SLUG}` | Used only in the default `ARTIFACTS_BUCKET_PREFIX`. Usually provided by Bitbucket. |
| AWS_REGION | Conditional** | `${AWS_REGION}` | Passed to `sam package` / `sam deploy` / `sam delete`. Explicitly validated only on the **IAM** path; still needed on OIDC or those commands receive an empty `--region`. |
| PIPELINE_USER_ACCESS_KEY_ID | Conditional | `${AWS_ACCESS_KEY_ID}` | Required on the IAM path (when OIDC is not selected). |
| PIPELINE_USER_SECRET_ACCESS_KEY | Conditional | `${AWS_SECRET_ACCESS_KEY}` | Required on the IAM path (when OIDC is not selected). |
| PIPELINE_EXECUTION_ROLE | Yes | `${PIPELINE_EXECUTION_ROLE}` | Always validated. IAM: assumed after build. OIDC: `AWS_ROLE_ARN` for web identity. |
| SAM_TEMPLATE | Yes | `template.yaml` | Always validated. Used by `sam build` only; still must be set in delete mode. |
| SAM_CONFIG_FILE | Yes | `samconfig.toml` | Always validated. Passed to build/package/deploy/delete. |
| CF_STACK_NAME | Yes | `${CF_STACK_NAME}` | Always validated. Stack name for deploy/delete. |
| CF_EXECUTION_ROLE | Yes | `${CF_EXECUTION_ROLE}` | Always validated. Used only as `--role-arn` on `sam deploy` (not on delete). |
| ARTIFACTS_BUCKET | Yes | `${ARTIFACTS_BUCKET}` | Always validated. S3 bucket for package/deploy/delete. |
| ARTIFACTS_BUCKET_PREFIX | Yes | `${BITBUCKET_DEPLOYMENT_ENVIRONMENT}/${BITBUCKET_REPO_SLUG}/${CF_STACK_NAME}` | Always validated. S3 prefix for package/deploy/delete. |
| CAPABILITIES | No | `NOCAPABILITIES` | Any value other than `NOCAPABILITIES` is passed as `--capabilities <value>` (no allow-list). `NOCAPABILITIES` omits the flag (samconfig may still supply capabilities). |
| DEBUG | No | `false` | Only the literal string `true` enables `--debug`. Other values (including `True` / `yes`) leave debug off. |
| DELETE | No | `false` | Only the literal string `true` selects delete mode. |
| FAIL_ON_EMPTY_CHANGESET | No | `false` | Only the literal string `true` selects `--fail-on-empty-changeset`; otherwise `--no-fail-on-empty-changeset`. Applied only on `sam deploy`. |
| SKIP_CHANGESET_EXECUTION | No | `false` | Only the literal string `true` adds `--no-execute-changeset` on `sam deploy`. |
| ROLE_SESSION_NAME | No | `BitbucketPipeline` | Sets `AWS_ROLE_SESSION_NAME` on the **OIDC** path only. IAM assume-role uses the fixed name `testing-stage-packaging`. |
| BITBUCKET_STEP_OIDC_TOKEN | No | `false` (script) / `${BITBUCKET_STEP_OIDC_TOKEN}` (`pipe.yml`) | Any value other than the literal `false` selects the OIDC path. Normally injected when the step has `oidc: true`. |

\*Required indirectly if you rely on the default artifact prefix and do not override `ARTIFACTS_BUCKET_PREFIX`.

\*\*Validated with a hard failure only when using IAM authentication.

Defaults that reference environment variables (except Bitbucket-injected `BITBUCKET_*` values) must be
set as Bitbucket variables or passed explicitly in the pipe block.

You must end up with valid AWS credentials via **IAM or OIDC**. If `sts get-caller-identity` fails,
the pipe exits.

**Not configurable:** the packaged template file name is fixed to `packaged-template.yaml`
(`OUTPUT_TEMPLATE_FILE` in the script). That file is written under `BITBUCKET_CLONE_DIR` during
package/deploy and remains in the step workspace afterward. The pipe also sets `SAM_CLI_TELEMETRY=0`.

Boolean pipe flags (`DEBUG`, `DELETE`, `FAIL_ON_EMPTY_CHANGESET`, `SKIP_CHANGESET_EXECUTION`) are
compared to the literal string `true` only.

**Exit status:** SAM commands are invoked through the Bitbucket pipes toolkit `run` helper. Each
`run` updates a shared `status` to that command's exit code; later commands still execute even if an
earlier one failed. The pipe ends with success only if the final `status` is `0` (typically the last
`sam` command that ran).

Delete mode still validates the same required variables as deploy mode at startup, even when a
variable is not passed to `sam delete` (for example `SAM_TEMPLATE` and `CF_EXECUTION_ROLE`).

## Details

### Deployment mode

Default mode. The pipe runs:

1. `sam build`

```bash
sam build ${PARAM_DEBUG} --template $SAM_TEMPLATE --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}"
```

2. `sam package`

```bash
sam package ${PARAM_DEBUG} --s3-bucket "${ARTIFACTS_BUCKET}" --s3-prefix "${ARTIFACTS_BUCKET_PREFIX}" --region "${AWS_REGION}" --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}" --output-template-file packaged-template.yaml
```

3. `sam deploy`

```bash
sam deploy ${PARAM_DEBUG} --s3-bucket "${ARTIFACTS_BUCKET}" --s3-prefix "${ARTIFACTS_BUCKET_PREFIX}" --region "${AWS_REGION}" --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}" --template packaged-template.yaml --stack-name ${CF_STACK_NAME} --role-arn "${CF_EXECUTION_ROLE}" ${CAPABILITY_OPTION} ${PARAM_FAIL_ON_EMPTY_CHANGESET} ${NO_EXECUTE_CHANGESET}
```

`${PARAM_FAIL_ON_EMPTY_CHANGESET}` is `--fail-on-empty-changeset` or `--no-fail-on-empty-changeset`
according to `FAIL_ON_EMPTY_CHANGESET`. `${NO_EXECUTE_CHANGESET}` is `--no-execute-changeset` when
`SKIP_CHANGESET_EXECUTION=true`, otherwise empty.

### Delete mode

Set `DELETE: 'true'`. The pipe skips `sam build`, `sam package`, and `sam deploy`, then runs
`sam delete` (after the IAM assume-role step when using IAM auth):

```bash
sam delete ${PARAM_DEBUG} --s3-bucket "${ARTIFACTS_BUCKET}" --s3-prefix "${ARTIFACTS_BUCKET_PREFIX}" --region "${AWS_REGION}" --config-file ${SAM_CONFIG_FILE} --config-env "${BITBUCKET_DEPLOYMENT_ENVIRONMENT}" --stack-name ${CF_STACK_NAME} --no-prompts
```

Startup validation still requires the same variables as deploy mode (including `SAM_TEMPLATE` and
`CF_EXECUTION_ROLE`), even though they are not arguments to `sam delete`.

### Authentication

Two schemes are supported: IAM and OIDC.

* **IAM:** set `PIPELINE_USER_ACCESS_KEY_ID` and `PIPELINE_USER_SECRET_ACCESS_KEY` (or rely on their
  defaults mapping to `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`). `AWS_REGION` is required on this
  path.
* **OIDC:** enable `oidc: true` on the Bitbucket step so `BITBUCKET_STEP_OIDC_TOKEN` is injected, and
  configure Bitbucket as a web identity provider in AWS. See the
  [Atlassian OIDC guide](https://support.atlassian.com/bitbucket-cloud/docs/deploy-on-aws-using-bitbucket-pipelines-openid-connect/).

If `BITBUCKET_STEP_OIDC_TOKEN` is anything other than the literal `false`, the OIDC path is used
(even if IAM keys are also present). With OIDC, `PIPELINE_EXECUTION_ROLE` is set as `AWS_ROLE_ARN`
and `ROLE_SESSION_NAME` maps to `AWS_ROLE_SESSION_NAME`.

## Examples

### Basic IAM deploy

```yaml
pipelines:
  default:
    - step:
        name: Deploy SAM application
        deployment: qa
        script:
          - pipe: trustep/aws-sam-custom-deploy:latest
            variables:
              AWS_REGION: $AWS_REGION
              PIPELINE_USER_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
              PIPELINE_USER_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
              PIPELINE_EXECUTION_ROLE: $PIPELINE_EXECUTION_ROLE
              CF_EXECUTION_ROLE: $CF_EXECUTION_ROLE
              CF_STACK_NAME: my-stack-name
              ARTIFACTS_BUCKET: my-artifacts-bucket-name
              SAM_TEMPLATE: template.yaml
              SAM_CONFIG_FILE: samconfig.toml
              CAPABILITIES: CAPABILITY_IAM
```

`BITBUCKET_CLONE_DIR`, `BITBUCKET_DEPLOYMENT_ENVIRONMENT`, and `BITBUCKET_REPO_SLUG` are normally
injected by Bitbucket. `ARTIFACTS_BUCKET_PREFIX` can be omitted to use the default
`${BITBUCKET_DEPLOYMENT_ENVIRONMENT}/${BITBUCKET_REPO_SLUG}/${CF_STACK_NAME}`.

### Review changeset without applying it

```yaml
- pipe: trustep/aws-sam-custom-deploy:latest
  variables:
    AWS_REGION: $AWS_REGION
    PIPELINE_USER_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
    PIPELINE_USER_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
    PIPELINE_EXECUTION_ROLE: $PIPELINE_EXECUTION_ROLE
    CF_EXECUTION_ROLE: $CF_EXECUTION_ROLE
    CF_STACK_NAME: my-stack-name
    ARTIFACTS_BUCKET: my-artifacts-bucket-name
    SAM_TEMPLATE: template.yaml
    SAM_CONFIG_FILE: samconfig.toml
    SKIP_CHANGESET_EXECUTION: 'true'
```

### Delete stack

```yaml
- pipe: trustep/aws-sam-custom-deploy:latest
  variables:
    AWS_REGION: $AWS_REGION
    PIPELINE_USER_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
    PIPELINE_USER_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
    PIPELINE_EXECUTION_ROLE: $PIPELINE_EXECUTION_ROLE
    CF_EXECUTION_ROLE: $CF_EXECUTION_ROLE
    CF_STACK_NAME: my-stack-name
    ARTIFACTS_BUCKET: my-artifacts-bucket-name
    SAM_TEMPLATE: template.yaml
    SAM_CONFIG_FILE: samconfig.toml
    DELETE: 'true'
```

## Troubleshooting

| Symptom | Likely cause | What to check |
| :------ | :----------- | :------------ |
| Missing variable / pipe exits early | Required env not set | Compare logs with the Variables table; set Bitbucket vars or pass them in the pipe block. |
| Config environment not found | `BITBUCKET_DEPLOYMENT_ENVIRONMENT` does not match `samconfig.toml` | Use `deployment: <env>` on the step and a matching `[<env>.deploy.parameters]` section. |
| Invalid credentials | IAM keys wrong or OIDC/trust misconfigured | Confirm secrets; if you used `sam pipeline bootstrap`, reuse its outputs. Otherwise ensure the identity can assume `PIPELINE_EXECUTION_ROLE`. |
| Access denied on S3 or CloudFormation | Role permissions incomplete | Prefer bootstrap-managed roles/bucket. Otherwise grant package/upload and stack deploy permissions on the execution roles. |
| Empty changeset failure | Stack unchanged and fail-on-empty enabled | Set `FAIL_ON_EMPTY_CHANGESET: 'false'` (default) or expect no-op deploys to fail when `true`. |
| ChangeSet created but stack not updated | Skip execution enabled | `SKIP_CHANGESET_EXECUTION: 'true'` only creates the changeset; apply it separately or rerun with `false`. |
| Template / config file not found | Wrong working directory or path | Paths are relative to `BITBUCKET_CLONE_DIR`; verify file names and clone layout. |
| Build needs Docker / `--use-container` | Pipe does not run containerized builds | Build natively in the image (Node 22 is available) or build artifacts before invoking the pipe. |
| Unexpected SAM CLI behavior/version | Tag mismatch | Check tags on [Docker Hub](https://hub.docker.com/r/trustep/aws-sam-custom-deploy/tags); pin `x.y.z` and confirm `sam --version` in the logs. |
| Pipe reports success/failure oddly after a mid-run error | Toolkit `run` keeps going | Inspect logs for every `sam` step; final status reflects the last `run` exit code. |

Enable `DEBUG: 'true'` for verbose SAM CLI output when investigating failures.

## Support

If you need help, or have an issue or feature request, use the
[GitHub repository](https://github.com/trustep/io.trustep.bitbucket.pipes.aws-sam-custom-deploy).

When reporting an issue, include:

* the pipe version (image tag)
* relevant logs and error messages
* steps to reproduce

## License

Copyright (c) 2022-2026 Trustep.
Apache 2.0 licensed, see [LICENSE](src/main/docker/LICENSE) file.
