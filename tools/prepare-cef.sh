#!/usr/bin/env sh
set -eu

CEF_VERSION="149.0.2+ged5b3fd+chromium-149.0.7827.53"
CEF_ARCHIVE="cef_binary_${CEF_VERSION}_macosx64.tar.bz2"
CEF_SHA1="68c2e28a41b95a2357efee2ee39dcfd06605b838"
CEF_URL="https://cef-builds.spotifycdn.com/${CEF_ARCHIVE}"
CEF_ROOT="var/cef/cef_binary_${CEF_VERSION}_macosx64"

mkdir -p var/downloads var/cef

if [ -d "${CEF_ROOT}" ]; then
  echo "CEF already prepared at ${CEF_ROOT}"
  exit 0
fi

if [ ! -f "var/downloads/${CEF_ARCHIVE}" ]; then
  curl -L -o "var/downloads/${CEF_ARCHIVE}" "${CEF_URL}"
fi

ACTUAL_SHA1="$(shasum "var/downloads/${CEF_ARCHIVE}" | awk '{print $1}')"
if [ "${ACTUAL_SHA1}" != "${CEF_SHA1}" ]; then
  echo "Invalid CEF archive checksum: ${ACTUAL_SHA1}" >&2
  exit 1
fi

tar -xjf "var/downloads/${CEF_ARCHIVE}" -C var/cef
echo "CEF prepared at ${CEF_ROOT}"

