#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

./tools/build-app.sh

BUILD_APP="${PROJECT_DIR}/build-xcode/src/Release/BabelChrome.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# Stop the installed app before replacing the bundle.
killall BabelChrome 2>/dev/null || true

if [ -d /Applications/BabelChrome.app ]; then
  rm -rf /Applications/BabelChrome.app
fi

cp -R "${BUILD_APP}" /Applications/BabelChrome.app
"${LSREGISTER}" -u "${BUILD_APP}" 2>/dev/null || true
"${LSREGISTER}" -f /Applications/BabelChrome.app

echo "Installed /Applications/BabelChrome.app"
