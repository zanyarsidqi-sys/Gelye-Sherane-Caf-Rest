#!/usr/bin/env python3
"""Offline static migration dependency scan; not a substitute for PostgreSQL tests."""
import pathlib,re,sys
root=pathlib.Path(__file__).resolve().parents[1]/'supabase'/'migrations'
files={p.name:p.read_text(encoding='utf-8') for p in root.glob('*.sql')}
if not files:sys.exit('No migration files found')
created=set()
for s in files.values():
 created.update(m.group(1).lower() for m in re.finditer(r'create\s+table\s+(?:if\s+not\s+exists\s+)?(?:public\.)?(gs_[a-z0-9_]+)',s,re.I))
missing=[]
for name,s in sorted(files.items()):
 for t in sorted(set(re.findall(r'\b(gs_[a-z0-9_]+)\b',s,re.I))):
  if t.lower() not in created and re.search(r'\b(?:from|join|update|into|on)\s+(?:public\.)?'+re.escape(t)+r'\b',s,re.I):
   missing.append((name,t))
print('SQL files:',len(files),'CREATE TABLE names:',len(created))
print('Potential missing table definitions:',len(missing))
for name,t in missing:print('  ',name,t)
if missing:sys.exit(2)
