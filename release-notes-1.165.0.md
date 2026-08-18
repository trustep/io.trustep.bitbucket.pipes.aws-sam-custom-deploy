## What's Changed

### Versioning
- Pipe image tags now track the embedded AWS SAM CLI version (target **1.165.0**).
- Default tags without suffix remain for compatibility: `1.165.0` and `latest` (`provided.al2023` + NVM Node 22).

### Image variants
- Added a static catalog (`src/main/docker/variants.json`) publishing runtime-specific images:
  - `*-nodejs24.x` / `*-nodejs22.x`
  - `*-python3.14` / `*-python3.13` / `*-python3.12`
- Consumers choose the tag in `pipe:` (for example `trustep/aws-sam-custom-deploy:latest-python3.12`).

### Documentation
- Expanded README: versioning guidance (`latest` vs pinned), roles/auth flow, samconfig contract, troubleshooting, and variant matrix.

### CI
- Builds and pushes all catalog variants on feature/develop/release/main.
- Updates Docker Hub repository description from README on release and main.
- Publishes this file as the GitHub Release body for `v1.165.0`.
- Upgraded `actions/checkout` to v7.

## Docker tags

| Tag | Base |
| --- | --- |
| `1.165.0` / `latest` | `build-provided.al2023` + NVM 22 |
| `1.165.0-nodejs24.x` / `latest-nodejs24.x` | `build-nodejs24.x` |
| `1.165.0-nodejs22.x` / `latest-nodejs22.x` | `build-nodejs22.x` |
| `1.165.0-python3.14` / `latest-python3.14` | `build-python3.14` |
| `1.165.0-python3.13` / `latest-python3.13` | `build-python3.13` |
| `1.165.0-python3.12` / `latest-python3.12` | `build-python3.12` |

## Links

- [README](https://github.com/trustep/io.trustep.bitbucket.pipes.aws-sam-custom-deploy/blob/main/README.md)
- [Docker Hub tags](https://hub.docker.com/r/trustep/aws-sam-custom-deploy/tags)
