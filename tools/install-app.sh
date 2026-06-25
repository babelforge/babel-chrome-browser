#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

./tools/build-app.sh

BUILD_APP="${PROJECT_DIR}/build-xcode/src/Release/BabelChrome.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
EXTENSION_HOST_PATTERN="/Applications/BabelChrome.app/Contents/Resources/ExtensionHost/public/index.php"
LEGACY_LOCAL_SERVICE_PATTERN="/Applications/BabelChrome.app/Contents/Resources/LocalServices/viewer/public/index.php"

# Stop the installed app and its local PHP service before replacing the bundle.
killall BabelChrome 2>/dev/null || true
if command -v pkill >/dev/null 2>&1; then
  pkill -f "${EXTENSION_HOST_PATTERN}" 2>/dev/null || true
  pkill -f "${LEGACY_LOCAL_SERVICE_PATTERN}" 2>/dev/null || true
fi

if [ -d /Applications/BabelChrome.app ]; then
  rm -rf /Applications/BabelChrome.app
fi

cp -R "${BUILD_APP}" /Applications/BabelChrome.app
"${LSREGISTER}" -u "${BUILD_APP}" 2>/dev/null || true
"${LSREGISTER}" -f /Applications/BabelChrome.app

echo "Installed /Applications/BabelChrome.app"
