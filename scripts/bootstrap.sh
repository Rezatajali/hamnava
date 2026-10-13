#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Install Flutter SDK first: https://docs.flutter.dev/install'
  exit 1
fi
flutter pub get
flutter analyze
flutter test
flutter build web --release
printf '%s\n' 'Ready: flutter run -d chrome' 'Deploy after reviewing rules: firebase deploy --project hamnava-67a58 --only firestore:rules,hosting'
