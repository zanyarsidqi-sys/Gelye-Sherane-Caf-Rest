#!/usr/bin/env python3
"""Check release metadata without publishing or contacting production."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
version=(root/'release/VERSION').read_text().strip()
workflow=(root/'.github/workflows/iphone_web_staging.yml').read_text()
source=(root/'lib/shared/app_release_version.dart').read_text()
assert re.fullmatch(r"[0-9]+(?:\.[0-9]+){3}", version), 'Invalid four-part release version'
assert "'release/VERSION'" in workflow, 'Version changes do not trigger staging build'
assert '--dart-define="APP_RELEASE_VERSION=$RELEASE_VERSION"' in workflow, 'Flutter build missing version define'
assert 'build/web/release-version.txt' in workflow, 'Artifact version manifest missing'
assert "String.fromEnvironment('APP_RELEASE_VERSION'" in source, 'UI version is not build-configured'
print(f'PASS: release {version} source/build/artifact version wiring (not a live deployment test)')
