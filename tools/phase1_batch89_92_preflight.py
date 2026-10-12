#!/usr/bin/env python3
"""Offline static preflight: does NOT compile Dart or verify native builds."""
from pathlib import Path
import re, sys, json
root = Path(__file__).resolve().parents[1]
lib = root / 'lib'
files = list(lib.rglob('*.dart'))
assert files, 'No Dart source files'
missing=[]
for f in files:
    data=f.read_text(encoding='utf-8')
    for relative in re.findall(r"(?:import|export|part)\s+['\"](\.[^'\"]+)['\"]",data):
        if not (f.parent/relative).is_file(): missing.append((str(f.relative_to(root)),relative))
assert not missing, f'Missing local imports: {missing[:20]}'
source=(lib/'app/cafe_app.dart').read_text(encoding='utf-8')
assert 'final changeEpoch = ++_languageChangeEpoch;' in source
assert 'loadEpoch == _languageChangeEpoch' in source
assert 'if (mounted) setState(() => _language = code);' in source
assert (root/'tools/bootstrap_native_platforms.sh').is_file()
for required in ('pubspec.yaml','lib/main.dart'):
    assert (root/required).is_file(), required
print(json.dumps({'status':'PASS','dart_files':len(files),'missing_relative_imports':len(missing),'native_scaffold_present':{p:(root/p).is_dir() for p in ('android','ios','windows')},'flutter_compiled':False},indent=2))
