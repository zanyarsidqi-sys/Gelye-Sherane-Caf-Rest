#!/usr/bin/env python3
"""Offline-only migration reconciliation. Never connects to a database."""
import argparse,collections,hashlib,json,pathlib,sys

def verify(root):
    plan=json.loads((root/'PHASE1_STEP11_FRESH_DB_RENUMBER_PLAN.json').read_text())
    rows=plan['mapping']; errors=[]; versions=[]; names=set()
    folder=root/'supabase'/'migrations'
    disk={p.name:p for p in folder.glob('*.sql')}
    for item in rows:
        old=item['original']; new=item['proposed_for_fresh_database_only']
        if old in names: errors.append('repeated source: '+old)
        names.add(old)
        if old not in disk: errors.append('missing: '+old);continue
        if hashlib.sha256(disk[old].read_bytes()).hexdigest()!=item['sha256']: errors.append('hash mismatch: '+old)
        if not new.endswith('.sql') or len(new.split('_')[0])!=14 or not new.split('_')[0].isdigit(): errors.append('invalid target version: '+new)
        versions.append(new.split('_')[0])
    if set(disk)!=names: errors.append('migration inventory mismatch')
    if len(set(versions))!=len(versions): errors.append('duplicate proposed version')
    if versions!=sorted(versions): errors.append('non-monotonic proposed order')
    if plan.get('deployment_authorized') is not False: errors.append('deployment flag must remain false')
    if plan.get('production_migration_history_checked') is not False: errors.append('history flag is not verified')
    return {'passed':not errors,'migration_count':len(disk),'proposed_count':len(versions),'errors':errors,'database_execution':'NOT RUN','deployment_authorized':False}

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--project-root',type=pathlib.Path,default=pathlib.Path(__file__).resolve().parents[1])
    parser.add_argument('--database-url',default=None,help='Prohibited: this tool is offline-only')
    parser.add_argument('--execute',action='store_true',help='Prohibited: execution requires separately reviewed procedure')
    args=parser.parse_args()
    if args.execute or args.database_url:
        print('BLOCKED: database connections and execution are prohibited by this offline tool',file=sys.stderr)
        return 2
    result=verify(args.project_root)
    print(json.dumps(result,indent=2))
    return 0 if result['passed'] else 1
if __name__=='__main__': sys.exit(main())
