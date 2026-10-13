#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  printf '%s\n' 'Flutter is required: https://docs.flutter.dev/install'
  exit 1
fi
flutter pub get
flutter run -d chrome --web-port=8765
