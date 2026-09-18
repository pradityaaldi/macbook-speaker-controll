#!/bin/bash
set -euo pipefail

REPO="pradityaaldi/macbook-speaker-controll"
APP_NAME="Speaker Control"
DEST="/Applications/${APP_NAME}.app"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "Speaker Control is a macOS app; this installer only runs on macOS." >&2
  exit 1
fi

if [ ! -w "$(dirname "${DEST}")" ]; then
  echo "$(dirname "${DEST}") is not writable by $(whoami)." >&2
  echo "Re-run with: curl -fsSL https://raw.githubusercontent.com/${REPO}/main/install.sh | sudo bash" >&2
  exit 1
fi

echo "Looking up the latest release of ${REPO}..."
ASSET_URL="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*\.zip"' \
  | head -1 \
  | sed 's/.*"\(https[^"]*\)".*/\1/')"

if [ -z "${ASSET_URL}" ]; then
  echo "No .zip asset found in the latest release." >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Downloading $(basename "${ASSET_URL}")..."
curl -fsSL "${ASSET_URL}" -o "${TMP_DIR}/app.zip"
ditto -x -k "${TMP_DIR}/app.zip" "${TMP_DIR}/unpacked"

if [ ! -d "${TMP_DIR}/unpacked/${APP_NAME}.app" ]; then
  echo "The downloaded archive does not contain ${APP_NAME}.app." >&2
  exit 1
fi

osascript -e "quit app \"${APP_NAME}\"" >/dev/null 2>&1 || true

rm -rf "${DEST}"
ditto "${TMP_DIR}/unpacked/${APP_NAME}.app" "${DEST}"
xattr -dr com.apple.quarantine "${DEST}" 2>/dev/null || true
mdimport "${DEST}" >/dev/null 2>&1 || true

echo "Installed ${DEST}"
echo "Launch it with: open -a \"${APP_NAME}\""
