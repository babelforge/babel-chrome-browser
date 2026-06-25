#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)"
MODULES_PROJECT_DIR="$(CDPATH= cd -- "${PROJECT_DIR}/../babel-chrome-modules" && pwd)"

BABEL_CHROME_WORKSPACE="${PROJECT_DIR}" "${MODULES_PROJECT_DIR}/tools/dev2prod.sh" "$@"
