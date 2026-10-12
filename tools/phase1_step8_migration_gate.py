#!/usr/bin/env python3
"""Read-only migration integrity gate; never deploys or renames SQL."""
import pathlib, hashlib, json, collections, sys
base=pathlib.Path(__file__).resolve().parents[1]
manifest=json.loads((base/'PHASE1_STEP8_MIGRATION_MANIFEST.json').read_text())
folder=base/'supabase'/'migrations'
files={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in folder.glob('*.sql')}
expected=manifest['migration_sha256']
missing=sorted(set(expected)-set(files)); added=sorted(set(files)-set(expected))
changed=sorted(k for k in set(files)&set(expected) if files[k]!=expected[k])
versions=collections.Counter(k.split('_')[0] for k in files)
collisions={k:v for k,v in versions.items() if v>1}
print(json.dumps({'expected':len(expected),'actual':len(files),'missing':missing,'added':added,'changed':changed,'collision_groups':collisions},indent=2))
if missing or added or changed:sys.exit(2)
if collisions:sys.exit(3) # intentional deployment blocker
print('Ready for next checks; not production approval')
