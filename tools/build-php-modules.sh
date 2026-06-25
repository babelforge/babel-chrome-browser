#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_DIR="$(CDPATH= cd -- "${PROJECT_DIR}/.." && pwd)"

BABEL_CHROME_BROWSER_DIR="${PROJECT_DIR}" "${WORKSPACE_DIR}/tools/dev2prod.sh" "$@"
