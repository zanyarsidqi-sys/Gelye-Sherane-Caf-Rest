#!/usr/bin/env python3
"""Offline source checks only. Never claims live delivery or deployment."""
from pathlib import Path
import json, re, sys
root=Path(__file__).resolve().parents[1]
version=(root/'release/VERSION').read_text().strip()
app=(root/'lib/app/cafe_app.dart').read_text()
workflow=(root/'.github/workflows/flutter_validation.yml').read_text()
push=(root/'web/push_client.js').read_text()
checks={
 'version_semver': bool(re.fullmatch(r'\d+\.\d+\.\d+\.\d+',version)),
 'footer_single_source_placement': app.count('GelyeCompanyFooter(version: _installedVersion)')==1,
 'footer_uses_release_configuration': 'AppReleaseVersion.label' in app,
 'ci_release_version_build': 'APP_RELEASE_VERSION=$RELEASE_VERSION' in workflow,
 'ci_staging_artifact': 'actions/upload-artifact@v4' in workflow,
 'push_service_worker': (root/'web/push/sw.js').is_file(),
 'push_client_subscription': 'window.cafePushEnable' in push and 'window.cafePushDisable' in push,
 'saved_session_restoration': '_restoreSavedSession' in app,
}
report={'candidate_version':version,'source_checks':checks,
 'requires_manual_verification':['Flutter CI build succeeds','Login persists after browser restart without bypassing MFA','Exactly one footer displays candidate version','Web Push delivered on desktop browser','Web Push delivered on iPhone installed Home Screen app','Production remains unchanged until explicit Update authorization'],
 'release_ready':False}
(root/'release/STAGING_PREFLIGHT_REPORT.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
sys.exit(0 if all(checks.values()) else 1)
