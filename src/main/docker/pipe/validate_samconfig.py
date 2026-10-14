#!/usr/bin/env python3
"""Read-only check of the TOML given by SAM_CONFIG_FILE before invoking SAM."""

import sys
from pathlib import Path

VENDOR_DIR = Path(__file__).resolve().parent / "vendor"
sys.path.insert(0, str(VENDOR_DIR))

import tomli  # noqa: E402

SAM_CONFIG_VERSION = 0.1
DEPLOY_COMMANDS = ("global", "build", "package", "deploy")
DELETE_COMMANDS = ("global", "delete")


def main(argv):
    if len(argv) != 4:
        emit("Internal use: validate_samconfig.py <file> <config-env> <DELETE>")
        return 1

    config_path = argv[1]
    config_env = argv[2]
    delete_flag = argv[3]
    commands = DELETE_COMMANDS if delete_flag == "true" else DEPLOY_COMMANDS

    try:
        document = read_toml(config_path)
    except ValueError as exc:
        emit(str(exc))
        return 1

    try:
        check_version(document, config_path)
        environment = require_environment(document, config_path, config_env)
        check_command_sections(environment, config_path, config_env, commands)
    except ValueError as exc:
        emit(str(exc))
        return 1

    return 0


def read_toml(config_path):
    path = Path(config_path)
    if not path.exists():
        raise ValueError(f"SAM config file not found: {config_path}")
    if not path.is_file():
        raise ValueError(f"SAM config file is not a file: {config_path}")

    try:
        with path.open("rb") as handle:
            document = tomli.load(handle)
    except PermissionError as exc:
        raise ValueError(f"SAM config file not readable: {config_path}") from exc
    except OSError as exc:
        raise ValueError(f"SAM config file not readable: {config_path}") from exc
    except tomli.TOMLDecodeError as exc:
        raise ValueError(
            f"SAM config file is not valid TOML: {config_path} ({exc})"
        ) from exc

    if not isinstance(document, dict):
        raise ValueError(f"SAM config file must be a TOML table: {config_path}")
    return document


def check_version(document, config_path):
    if "version" not in document:
        raise ValueError(f"SAM config file {config_path}: missing required key 'version'")

    version = document["version"]
    if isinstance(version, bool) or not isinstance(version, float) or version != SAM_CONFIG_VERSION:
        raise ValueError(f"SAM config file {config_path}: key 'version' must be 0.1")


def require_environment(document, config_path, config_env):
    if config_env not in document:
        raise ValueError(
            f"SAM config file {config_path}: missing environment table [{config_env}]"
        )

    environment = document[config_env]
    if not isinstance(environment, dict):
        raise ValueError(
            f"SAM config file {config_path}: [{config_env}] must be a table"
        )
    return environment


def check_command_sections(environment, config_path, config_env, commands):
    for command in commands:
        if command not in environment:
            continue

        section = f"{config_env}.{command}"
        command_table = environment[command]
        if not isinstance(command_table, dict):
            raise ValueError(f"SAM config file {config_path}: [{section}] must be a table")

        if "parameters" not in command_table:
            continue
        if not isinstance(command_table["parameters"], dict):
            raise ValueError(
                f"SAM config file {config_path}: [{section}.parameters] must be a table"
            )


def emit(message):
    print(message, file=sys.stderr)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
