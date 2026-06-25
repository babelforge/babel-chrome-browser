#!/usr/bin/env sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_DIR="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_DIR}"

./tools/prepare-cef.sh

(
  cd "${PROJECT_DIR}/src/ExtensionHost"
  composer install
)

cmake \
  -G Xcode \
  -DPROJECT_ARCH=x86_64 \
  -DCMAKE_C_COMPILER=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang \
  -DCMAKE_CXX_COMPILER=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++ \
  -DCMAKE_OBJC_COMPILER=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang \
  -DCMAKE_OBJCXX_COMPILER=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++ \
  -S . \
  -B build-xcode

xcodebuild \
  -project build-xcode/BabelChrome.xcodeproj \
  -scheme BabelChrome \
  -configuration Release \
  -derivedDataPath build-xcode/DerivedData \
  build

echo "Built build-xcode/src/Release/BabelChrome.app"
