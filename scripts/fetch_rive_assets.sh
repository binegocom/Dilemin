#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET="$ROOT/mobile/assets/rive/web_icons_pack.riv"
EXPECTED_BLOB="0ac950339c756d60a70007e7255879f3941f3e43"
SOURCE="https://raw.githubusercontent.com/rive-app/rive-flutter/master/example/assets/web_icons_pack.riv"

command -v git >/dev/null || { echo 'Git is required' >&2; exit 1; }
command -v curl >/dev/null || { echo 'curl is required' >&2; exit 1; }
mkdir -p "$(dirname "$ASSET")"
if [[ -f "$ASSET" ]] && [[ "$(git hash-object "$ASSET")" == "$EXPECTED_BLOB" ]]; then
  echo 'Verified Rive vector asset is present.'
  exit 0
fi
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
curl --fail --location --silent --show-error --retry 3 --connect-timeout 15 --max-time 120 "$SOURCE" --output "$TMP"
ACTUAL_BLOB="$(git hash-object "$TMP")"
if [[ "$ACTUAL_BLOB" != "$EXPECTED_BLOB" ]]; then
  echo "Rive asset checksum mismatch: $ACTUAL_BLOB" >&2
  exit 1
fi
mv "$TMP" "$ASSET"
echo 'Downloaded and verified upstream Rive asset.'
