## What's Changed

### Versioning
- Embedded AWS SAM CLI advances from **1.165.0** to **1.169.0** (upstream [v1.169.0](https://github.com/aws/aws-sam-cli/releases/tag/v1.169.0)).
- Default tags without suffix remain for compatibility: `1.169.0` and `latest` (`provided.al2023` + NVM Node 22).

### Image variants
- Catalog unchanged (`src/main/docker/variants.json`):
  - `*-nodejs24.x` / `*-nodejs22.x`
  - `*-python3.14` / `*-python3.13` / `*-python3.12`
- Consumers choose the tag in `pipe:` (for example `trustep/aws-sam-custom-deploy:1.169.0-python3.12`).

### SAM config validation
- Before `sam build`, `sam package`, `sam deploy`, or `sam delete`, the pipe reads `SAM_CONFIG_FILE` from `BITBUCKET_CLONE_DIR` and stops if the file is missing, unreadable, or not valid TOML.
- `version` must be the float `0.1`, and a table named exactly `BITBUCKET_DEPLOYMENT_ENVIRONMENT` must exist.
- Deploy mode checks present `global`, `build`, `package`, and `deploy` sections; delete mode checks `global` and `delete`. A present section or its `parameters` value must be a table. Other keys are optional. The file is not modified, and the same path is passed as `--config-file`.
- Details: [samconfig contract](README.md#samconfig-contract).

### CI
- Same deploy policy: feature, develop, release and main rebuild every catalog variant against the target SAM version.
- Publishes this file as the GitHub Release body for `v1.169.0`.

## Docker tags

| Tag | Base |
| --- | --- |
| `1.169.0` / `latest` | `build-provided.al2023` + NVM 22 |
| `1.169.0-nodejs24.x` / `latest-nodejs24.x` | `build-nodejs24.x` |
| `1.169.0-nodejs22.x` / `latest-nodejs22.x` | `build-nodejs22.x` |
| `1.169.0-python3.14` / `latest-python3.14` | `build-python3.14` |
| `1.169.0-python3.13` / `latest-python3.13` | `build-python3.13` |
| `1.169.0-python3.12` / `latest-python3.12` | `build-python3.12` |

## Links

- [README](https://github.com/trustep/io.trustep.bitbucket.pipes.aws-sam-custom-deploy/blob/main/README.md)
- [Docker Hub tags](https://hub.docker.com/r/trustep/aws-sam-custom-deploy/tags)
- [Previous notes (1.165.0)](release-notes-1.165.0.md)
