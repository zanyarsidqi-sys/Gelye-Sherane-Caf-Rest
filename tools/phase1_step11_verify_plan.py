#!/usr/bin/env python3
"""Offline read-only Step 11 proposal self-test."""
import json,pathlib,hashlib,collections,sys
root=pathlib.Path(__file__).resolve().parents[1]
report=json.loads((root/'PHASE1_STEP11_FRESH_DB_RENUMBER_PLAN.json').read_text())
entries=report['mapping']; versions=[e['proposed_for_fresh_database_only'].split('_')[0] for e in entries]
assert len(entries)==report['migration_count']==len(set(versions))
assert all(len(v)==14 and v.isdigit() for v in versions)
for e in entries:
 p=root/'supabase'/'migrations'/e['original']
 assert p.is_file() and hashlib.sha256(p.read_bytes()).hexdigest()==e['sha256']
assert report['source_sql_modified'] is False
assert report['deployment_authorized'] is False
print('PASS: proposal uniqueness, mapping integrity, unchanged source hashes')
