#!/usr/bin/env python3
"""Check release metadata without publishing or contacting production."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
version=(root/'release/VERSION').read_text().strip()
workflow=(root/'.github/workflows/pages.yml').read_text()
staging_workflow=(root/'.github/workflows/validate-1.0.0.3-dashboard.yml').read_text()
source=(root/'lib/shared/app_release_version.dart').read_text()
assert re.fullmatch(r"[0-9]+(?:\.[0-9]+){3}", version), 'Invalid four-part release version'
assert 'release/VERSION' in workflow and 'REQUESTED_RELEASE_VERSION' in workflow, 'Production workflow must read and confirm release/VERSION'
assert '--dart-define="APP_RELEASE_VERSION=$RELEASE_VERSION"' in workflow, 'Flutter build missing version define'
assert 'release-version.txt' in workflow and 'release.json' in workflow, 'Production version manifest missing'
assert 'actions/upload-artifact@v4' in workflow, 'Production artifact upload missing'
assert 'actions/upload-artifact@v4' in staging_workflow, 'Staging artifact upload missing'
assert '--dart-define="APP_RELEASE_VERSION=$RELEASE_VERSION"' in staging_workflow, 'Staging build must show its candidate version'
assert "String.fromEnvironment('APP_RELEASE_VERSION'" in source, 'UI version is not build-configured'
print(f'PASS: release {version} source/build/artifact version wiring (not a live deployment test)')
