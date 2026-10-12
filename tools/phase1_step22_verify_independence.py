#!/usr/bin/env python3
"""Offline-only Supabase project identity and migration history evidence checker.
No network, secrets, credentials or DB execution. Requires independent project refs.
"""
import argparse, collections, hashlib, json, pathlib, re, sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
REF=re.compile(r'^[a-z]{20}$')
VERSION=re.compile(r'^\d{8,20}$')
def load_versions(path):
    raw=json.loads(path.read_text())
    if isinstance(raw,dict): raw=raw.get('versions')
    if not isinstance(raw,list): raise ValueError('history must be a JSON array or {"versions": [...]}')
    values=[]
    for x in raw:
        v=x.get('version') if isinstance(x,dict) else x
        if not isinstance(v,str) or not VERSION.fullmatch(v): raise ValueError('invalid version entry')
        values.append(v)
    return values

def check(root, evidence=None, history=None):
    mapping=json.loads((root/'PHASE1_STEP11_FRESH_DB_RENUMBER_PLAN.json').read_text())['mapping']
    errors=[]; originals=[]; proposed=[]
    for item in mapping:
        old=item['original']; new=item['proposed_for_fresh_database_only']
        path=root/'supabase'/'migrations'/old
        if not path.is_file() or hashlib.sha256(path.read_bytes()).hexdigest()!=item['sha256']:
            errors.append('source missing or hash mismatch: '+old)
        originals.append(old.split('_',1)[0]); proposed.append(new.split('_',1)[0])
    if len(set(proposed))!=len(proposed):errors.append('proposed version collision')
    report={'migration_count':len(mapping),'source_integrity_ok':not errors,'history_compared':False,'environment_independence_verified':False,'deployment_authorized':False,'database_contacted':False,'issues':errors}
    if evidence is not None:
        data=json.loads(pathlib.Path(evidence).read_text())
        if not isinstance(data,dict): raise ValueError('evidence must be JSON object')
        rest=data.get('rest_project_ref'); sweet=data.get('sweet_project_ref')
        valid=isinstance(rest,str) and isinstance(sweet,str) and bool(REF.fullmatch(rest)) and bool(REF.fullmatch(sweet)) and rest!=sweet
        if not valid: errors.append('distinct valid Rest and Sweet Supabase project refs required')
        report['environment_independence_verified']=valid
        # Do not print refs or retain credentials in reports.
    if history is not None:
        values=load_versions(pathlib.Path(history)); count=collections.Counter(values)
        duplicate=sorted(v for v,n in count.items() if n>1)
        known=set(originals)|set(proposed)
        unknown=sorted(set(values)-known)
        missing=sorted(set(originals)-set(values))
        report.update({'history_compared':True,'history_entries':len(values),'duplicate_history_versions':duplicate,'unknown_history_versions':unknown,'original_versions_not_in_export':missing,'history_complete_for_original_inventory':not missing})
        if duplicate:errors.append('duplicate versions in history export')
        if unknown:errors.append('unknown versions in history export')
        # Missing versions can mean fresh DB or incomplete export: never authorize deployment.
    return report

def main():
    p=argparse.ArgumentParser();p.add_argument('--project-root',type=pathlib.Path,default=ROOT)
    p.add_argument('--evidence',type=pathlib.Path);p.add_argument('--history',type=pathlib.Path)
    p.add_argument('--execute',action='store_true');args=p.parse_args()
    if args.execute:
        print('BLOCKED: this is a read-only offline verification tool',file=sys.stderr);return 2
    try: report=check(args.project_root,args.evidence,args.history)
    except (ValueError,OSError,KeyError,json.JSONDecodeError) as e:
        print('BLOCKED: invalid input: '+str(e),file=sys.stderr);return 2
    print(json.dumps(report,indent=2))
    return 0 if not report['issues'] else 1
if __name__=='__main__':sys.exit(main())
