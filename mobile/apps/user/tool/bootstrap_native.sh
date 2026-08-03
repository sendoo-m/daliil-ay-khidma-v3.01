#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter SDK 3.22+ is required.' >&2
  exit 1
fi

flutter create \
  --empty \
  --platforms=android,ios \
  --org=com.daliilaykhidma \
  --project-name=dalil_app \
  .

python3 tool/configure_deep_links.py
python3 tool/configure_firebase.py

flutter pub get
flutter gen-l10n

if [[ "${SKIP_CHECKS:-0}" != "1" ]]; then
  flutter analyze
  flutter test
fi

echo 'Native Android and iOS projects generated.'
echo 'Firebase client configuration installed. See FIREBASE_SETUP.md for server and signing secrets.'
