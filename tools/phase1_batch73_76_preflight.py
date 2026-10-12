#!/usr/bin/env python3
"""Offline Flutter import and critical-session invariant preflight; NOT a compiler."""
import pathlib, re, posixpath, sys
root=pathlib.Path(__file__).resolve().parents[1]
lib=root/'lib'
files=list(lib.rglob('*.dart'))
missing=[]
for f in files:
    src=f.read_text(encoding='utf-8')
    for item in re.findall(r"(?:import|export|part)\s+['\"]([^'\"]+)",src):
        if item.startswith('dart:'): continue
        if item.startswith('package:'):
            package, _, relative=item[8:].partition('/')
            if package != 'gelye_cafe_rest': continue
            destination=lib/relative
        else: destination=f.parent/item
        if not destination.is_file(): missing.append((str(f.relative_to(root)),item))
src=(lib/'app'/'cafe_app.dart').read_text(encoding='utf-8')
required=['_accessReviewBusy ||','_logoutRecoveryRequired ||',
          'client.auth.currentSession?.user.id != _authorizedUserId',
          'client.auth.currentUser?.id != _authorizedUserId',
          'AuthenticatorAssuranceLevels.aal2',
          'if (mounted && !_accessReviewBusy && !_logoutInProgress &&']
missing_guards=[x for x in required if x not in src]
print('Dart files:',len(files),'missing local imports:',len(missing),'missing guard patterns:',len(missing_guards))
for x in missing: print('MISSING IMPORT',x)
for x in missing_guards: print('MISSING GUARD',x)
sys.exit(1 if missing or missing_guards else 0)
