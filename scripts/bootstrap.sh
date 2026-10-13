#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Install Flutter SDK first: https://docs.flutter.dev/install'
  exit 1
fi
if [ -d web ]; then
  echo 'web/ already exists. Run flutter pub get, flutter test, and flutter run -d chrome.'
  exit 0
fi
generated_dir="$(mktemp -d)"
trap 'rm -rf "$generated_dir"' EXIT
flutter create --platforms=web --project-name hamnava "$generated_dir/scaffold"
cp -R "$generated_dir/scaffold/web" ./web
flutter pub get
flutter analyze
flutter test
echo 'Ready: flutter run -d chrome'
