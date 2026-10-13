#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  printf '%s\n' 'Flutter is required: https://docs.flutter.dev/install'
  exit 1
fi
if ! command -v node >/dev/null 2>&1 || ! command -v npx >/dev/null 2>&1; then
  printf '%s\n' 'Node.js 22+ and npm/npx are required for the Firebase CLI.'
  exit 1
fi
node -e 'if(Number(process.versions.node.split(".")[0]) < 22) { console.error("Use Node.js 22 or newer."); process.exit(1); }'
flutter pub get
flutter analyze
flutter test
flutter build web --release
printf '%s\n' 'Sign in with the Google account that owns hamnava-67a58.'
npx --yes firebase-tools@14 login
npx --yes firebase-tools@14 deploy --project hamnava-67a58 --only firestore:rules,hosting
printf '%s\n' 'Deployment finished. Open: https://hamnava-67a58.web.app'
