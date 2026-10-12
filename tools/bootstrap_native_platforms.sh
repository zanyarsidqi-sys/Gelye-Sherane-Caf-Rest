#!/usr/bin/env bash
# Generate official Flutter runners on the appropriate host; preserve lib/ and SQL.
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter SDK not found. Install Flutter and rerun.' >&2
  exit 2
fi
case "$(uname -s)" in
  Darwin) platforms=android,ios ;;
  Linux) platforms=android ;;
  MINGW*|MSYS*|CYGWIN*) platforms=android,windows ;;
  *) echo 'Unsupported host. Use macOS, Linux, or Windows.' >&2; exit 2 ;;
esac
flutter create --platforms="$platforms" --project-name=gelye_cafe_rest --org=com.gelyesherane .
flutter pub get
flutter analyze
flutter test
printf 'Generated platform runners for %s; run signing and platform builds on supported hosts.\n' "$platforms"
