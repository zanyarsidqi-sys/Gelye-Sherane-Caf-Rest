#!/usr/bin/env python3
"""Offline build and POS integration regression preflight (not Dart compilation)."""
from pathlib import Path
import re
root=Path(__file__).resolve().parents[1]
source=(root/'lib/services/pos_heartbeat_service.dart').read_text()
boot=(root/'tools/bootstrap_native_platforms.sh').read_text()
ci=(root/'.github/workflows/pages.yml').read_text() + (root/'.github/workflows/validate-1.0.0.2-staging.yml').read_text()
checks={
 'separate_pos_namespace': "gelye_cafe_rest_pos_device_v3_${user.id}" in source,
 'old_shared_namespace_removed': "'cafe_pos_device_v2_${user.id}'" not in source,
 'pos_select_account_recheck': source.count('if (_prefix != prefix)') >= 2,
 'heartbeat_account_recheck': 'if (id == null || _prefix != originalPrefix) return;' in source,
 'linux_android_only': 'Linux) platforms=android' in boot,
 'mac_ios_supported': 'Darwin) platforms=android,ios' in boot,
 'ci_android_debug_build': 'flutter build apk --debug' in ci,
 'ci_web_analyze_tests': all(x in ci for x in ('flutter analyze','flutter test','flutter build web --release')),
}
missing=[]
for f in (root/'lib').rglob('*.dart'):
 txt=f.read_text()
 for imp in re.findall(r"import\s+['\"](\.[^'\"]+)['\"]",txt):
  if not (f.parent/imp).resolve().is_file(): missing.append(f'{f.relative_to(root)} -> {imp}')
checks['relative_imports_resolve']=not missing
for k,v in checks.items(): print(('PASS' if v else 'FAIL'),k)
if missing:print('Missing imports:',missing)
raise SystemExit(0 if all(checks.values()) else 1)
