from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
version = (root/'release/VERSION').read_text().strip()
assert re.fullmatch(r'\d+\.\d+\.\d+\.\d+', version)
workflow = (root/'.github/workflows/pages.yml').read_text()
staging_workflow = (root/'.github/workflows/validate-1.0.0.3-dashboard.yml').read_text()
assert 'release/VERSION' in workflow
assert '"User-Agent": "GelyeProductionVerifier/1.0"' in workflow, 'Live verifier must send an accepted user agent'
assert '--dart-define="APP_RELEASE_VERSION=$RELEASE_VERSION"' in workflow
assert '--dart-define="APP_RELEASE_VERSION=$RELEASE_VERSION"' in staging_workflow
release = (root/'lib/shared/app_release_version.dart').read_text()
assert "String.fromEnvironment('APP_RELEASE_VERSION'" in release
assert 'AppReleaseVersion.label' in (root/'lib/app/cafe_app.dart').read_text()
assert 'AppReleaseVersion.label' in (root/'lib/screens/dashboard/dashboard_screen.dart').read_text()
print('Release version wiring: PASS')
