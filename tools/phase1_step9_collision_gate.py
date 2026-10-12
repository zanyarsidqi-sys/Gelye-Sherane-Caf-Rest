#!/usr/bin/env python3
"""Fail closed when migration version prefixes collide."""
from pathlib import Path
from collections import Counter
import sys
root=Path(__file__).resolve().parents[1]
files=list((root/'supabase'/'migrations').glob('*.sql'))
versions=Counter(p.name.split('_')[0] for p in files)
collisions={k:v for k,v in versions.items() if v>1}
print(f'Migrations: {len(files)}; duplicate version groups: {len(collisions)}')
if collisions:
 print('BLOCKED: resolve migration history and versions before deployment')
 sys.exit(2)
print('Unique migration version prefixes')
