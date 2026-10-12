#!/usr/bin/env python3
"""Phase 1 Step 15: offline migration deployment guard; NEVER connects to a DB."""
import argparse, hashlib, json, pathlib, re, subprocess, sys, tempfile

def check(root):
    plan=json.loads((root/'PHASE1_STEP11_FRESH_DB_RENUMBER_PLAN.json').read_text())
    migrations=root/'supabase'/'migrations'
    mapping=plan['mapping']
    actual={p.name for p in migrations.glob('*.sql')}
    expected={item['original'] for item in mapping}
    errors=[]
    if actual!=expected: errors.append('migration inventory mismatch')
    staged=[item['proposed_for_fresh_database_only'] for item in mapping]
    if len(staged)!=len(set(staged)): errors.append('duplicate staged migration versions')
    risky=[]
    for item in mapping:
        source=migrations/item['original']
        if not source.is_file(): continue
        data=source.read_bytes()
        if hashlib.sha256(data).hexdigest()!=item['sha256']: errors.append('hash mismatch: '+item['original'])
        # Advisory only: matches can occur in comments and strings.
        sql=data.decode('utf-8',errors='replace')
        if re.search(r'\b(?:DROP\s+(?:TABLE|SCHEMA|POLICY|FUNCTION)|TRUNCATE\s+|DELETE\s+FROM)\b',sql,re.I):
            risky.append(item['original'])
    return {'step':15,'mode':'offline_only','database_executed':False,
            'migration_count':len(mapping),'hash_and_inventory_passed':not errors,
            'unique_staged_names':len(staged)==len(set(staged)),
            'potentially_destructive_sql_review_count':len(risky),
            'potentially_destructive_sql_review_files':risky,
            'errors':errors,'production_deployment_approved':False}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--json-output',help='Optional output report file')
    args=parser.parse_args()
    root=pathlib.Path(__file__).resolve().parents[1]
    result=check(root)
    output=json.dumps(result,indent=2,ensure_ascii=False)
    print(output)
    if args.json_output: pathlib.Path(args.json_output).write_text(output+'\n')
    return 0 if not result['errors'] else 1
if __name__=='__main__': sys.exit(main())
