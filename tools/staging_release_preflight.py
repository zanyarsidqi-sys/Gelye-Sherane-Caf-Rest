#!/usr/bin/env python3
"""Offline source checks only. Never claims live delivery or deployment."""
from pathlib import Path
from collections import Counter
import json, re, sys
root=Path(__file__).resolve().parents[1]
version=(root/'release/VERSION').read_text().strip()
app=(root/'lib/app/cafe_app.dart').read_text()
release_version_source=(root/'lib/shared/app_release_version.dart').read_text()
staging_workflows=sorted((root/'.github/workflows').glob(f'validate-{version}-*.yml'))
validation_workflow=staging_workflows[0].read_text() if staging_workflows else ''
production_workflow=(root/'.github/workflows/pages.yml').read_text()
push=(root/'web/push_client.js').read_text()
migrations=list((root/'supabase/migrations').glob('*.sql'))
menu_migrations=[path for path in migrations if path.name.endswith('_menu_management_approval.sql')]
migration_prefixes=Counter(path.name.split('_',1)[0] for path in migrations)
menu_migration_prefix=menu_migrations[0].name.split('_',1)[0] if len(menu_migrations)==1 else ''
checks={
 'version_semver': bool(re.fullmatch(r'\d+\.\d+\.\d+\.\d+',version)),
 'project_footer_removed': 'GelyeCompanyFooter' not in app,
 'release_version_uses_build_configuration': "String.fromEnvironment('APP_RELEASE_VERSION'" in release_version_source,
 'ci_release_version_build': 'APP_RELEASE_VERSION=$RELEASE_VERSION' in production_workflow,
 'ci_production_manual_dispatch': 'workflow_dispatch:' in production_workflow,
 'ci_staging_artifact': 'actions/upload-artifact@v4' in validation_workflow,
 'ci_staging_version_matches': f'APP_RELEASE_VERSION={version}' in validation_workflow,
 'ci_staging_branch_matches': any(
  version in branch
  for branch in re.findall(
   r'(?m)^\s*-\s*(staging/release-[\w./-]+)\s*$', validation_workflow
  )
 ),
 'menu_migration_has_unique_14_digit_version': bool(
  re.fullmatch(r'\d{14}',menu_migration_prefix)
  and migration_prefixes[menu_migration_prefix] == 1
 ),
 'ci_staging_menu_backend_gate': 'gs_menu_public_catalog' in validation_workflow,
 'push_service_worker': (root/'web/push/sw.js').is_file(),
 'push_client_subscription': 'window.cafePushEnable' in push and 'window.cafePushDisable' in push,
 'saved_session_restoration': '_restoreSavedSession' in app,
}
report={'candidate_version':version,'source_checks':checks,
 'requires_manual_verification':['Release-specific staging catalog migration and employee-grant preservation verified','Combined floor map and Live Orders tested on phone and desktop','Existing table, order, reservation, and payment records remain unchanged','Flutter CI build succeeds','Login persists after browser restart without bypassing MFA','Web Push delivered on desktop browser','Web Push delivered on iPhone installed Home Screen app','Production remains unchanged until explicit Update authorization'],
 'release_ready':False}
(root/'release/STAGING_PREFLIGHT_REPORT.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
sys.exit(0 if all(checks.values()) else 1)
