#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
for command_name in flutter php composer python3; do
  command -v "$command_name" >/dev/null || { echo "Missing: $command_name" >&2; exit 1; }
done

if [[ ! -f "$ROOT/backend/artisan" ]]; then
  composer create-project laravel/laravel "$ROOT/backend" '^12.0' --no-interaction
fi
if [[ ! -d "$ROOT/backend/vendor/laravel/sanctum" ]]; then
  (cd "$ROOT/backend" && composer require laravel/sanctum --no-interaction)
fi
python3 "$ROOT/scripts/register_laravel_api.py" "$ROOT/backend/bootstrap/app.php"
cp -R "$ROOT/backend-overlay/." "$ROOT/backend/"

if [[ ! -d "$ROOT/mobile/android" || ! -d "$ROOT/mobile/ios" ]]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  flutter create --platforms=android,ios --project-name=dilemin --org=app.dilemin "$TMP/dilemin"
  cp -R "$TMP/dilemin/android" "$ROOT/mobile/android"
  cp -R "$TMP/dilemin/ios" "$ROOT/mobile/ios"
  MOBILE_DIR="$ROOT/mobile" python3 - <<'PYLOCAL'
from pathlib import Path
import os, plistlib
root = Path(os.environ['MOBILE_DIR'])
manifest = root / 'android/app/src/main/AndroidManifest.xml'
if manifest.exists():
    manifest_xml = manifest.read_text().replace('android:label="dilemin"', 'android:label="Dılêmın"')
    if 'android.permission.INTERNET' not in manifest_xml:
        manifest_xml = manifest_xml.replace('<application', '<uses-permission android:name="android.permission.INTERNET" />\n    <application', 1)
    manifest.write_text(manifest_xml)
plist = root / 'ios/Runner/Info.plist'
if plist.exists():
    with plist.open('rb') as f: data = plistlib.load(f)
    data['CFBundleDisplayName'] = 'Dılêmın'
    data['NSPhotoLibraryUsageDescription'] = 'Choose a profile photo to share after moderation.'
    with plist.open('wb') as f: plistlib.dump(data, f)
PYLOCAL
fi

bash "$ROOT/scripts/fetch_rive_assets.sh"
(cd "$ROOT/mobile" && flutter pub get && flutter gen-l10n && flutter analyze && flutter test)
(cd "$ROOT/backend" && php artisan route:list --path=api)

echo 'Scaffold initialized. Configure a dedicated PostgreSQL DB and Redis. Review migrations before applying.'
