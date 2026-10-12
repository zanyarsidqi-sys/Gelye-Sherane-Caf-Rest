#!/usr/bin/env python3
"""Read-only migration naming audit. Run: python3 tools/audit_migrations.py"""
from pathlib import Path
from collections import defaultdict
import sys
root = Path(__file__).resolve().parents[1]
folder = root / 'supabase' / 'migrations'
if not folder.is_dir():
    sys.exit('Missing supabase/migrations directory')
files = sorted(folder.glob('*.sql'))
groups = defaultdict(list)
for file in files:
    version = file.name.split('_', 1)[0]
    groups[version].append(file.name)
collisions = {v: names for v, names in groups.items() if len(names) > 1}
print(f'Migration files: {len(files)}; colliding prefixes: {len(collisions)}')
for version, names in sorted(collisions.items()):
    print(f'COLLISION {version}:')
    for name in names:
        print('  ' + name)
if collisions:
    sys.exit(1)
print('PASS: no duplicate version prefixes (not a SQL validity check)')
