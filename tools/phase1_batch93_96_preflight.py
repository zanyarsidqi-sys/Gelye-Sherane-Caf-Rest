#!/usr/bin/env python3
"""Offline checks for Steps 93-96; Flutter SDK required for real compile."""
from pathlib import Path
import re, json, subprocess, shutil
r=Path(__file__).resolve().parents[1]
s=(r/'lib/app/cafe_app.dart').read_text()
checks={
 'serialized_favorite_writes': '_favoriteWriteTail.then((_) async {' in s and '_favoriteWriteTail = operation;' in s,
 'account_scoped_favorite_reset': '_authorizedUserId != Supabase.instance.client.auth.currentUser?.id) return;\n    setState(() => _favoriteSectionIds.clear());' in s,
 'write_generation_guard': 'generation != _favoritesGeneration' in s,
 'native_bootstrap_script': (r/'tools/bootstrap_native_platforms.sh').is_file(),
 'flutter_ci_workflow': (r/'.github/workflows/validate-1.0.0.2-staging.yml').is_file() and (r/'.github/workflows/pages.yml').is_file(),
 'dart_sources_present': len(list((r/'lib').rglob('*.dart'))) > 100,
}
missing=[]
for f in (r/'lib').rglob('*.dart'):
 for rel in re.findall(r"(?:import|export|part)\s+['\"](\.[^'\"]+)['\"]", f.read_text()):
  if not (f.parent/rel).is_file(): missing.append((str(f),rel))
checks['relative_imports_resolve']=not missing
assert all(checks.values()),checks
print(json.dumps({'checks':checks,'flutter_available':bool(shutil.which('flutter')),'missing_imports':missing,'status':'PASS'},indent=2))
