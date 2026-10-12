#!/usr/bin/env python3
"""Read-only migration history comparison; never connects to a database."""
import argparse, csv, hashlib, json, pathlib, re, sys
ROOT=pathlib.Path(__file__).resolve().parents[1]
def run(history=None):
    plan=json.loads((ROOT/'PHASE1_STEP11_FRESH_DB_RENUMBER_PLAN.json').read_text())
    entries=plan['mapping']; migration_dir=ROOT/'supabase'/'migrations'
    problems=[]; originals=set(); proposed=set()
    for e in entries:
        original=e['original']; new=e['proposed_for_fresh_database_only']
        p=migration_dir/original
        if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=e['sha256']:problems.append('missing or changed: '+original)
        if original in originals or new in proposed:problems.append('duplicate mapping: '+original)
        originals.add(original);proposed.add(new)
    result={'source_files':len(entries),'source_integrity_ok':not problems,'history_supplied':history is not None,'database_contacted':False,'deployment_authorized':False,'issues':problems}
    if history is not None:
        path=pathlib.Path(history)
        if path.suffix.lower()=='.json':
            raw=json.loads(path.read_text()); values=raw.get('versions',raw) if isinstance(raw,dict) else raw
            versions=[str(x.get('version','')) if isinstance(x,dict) else str(x) for x in values]
        else:
            with path.open(newline='') as f:
                rows=list(csv.DictReader(f));versions=[str(x.get('version','')) for x in rows]
        versions=[v.strip() for v in versions if v.strip()]
        valid=all(re.fullmatch(r'\d{8,20}',v) for v in versions)
        result.update({'history_entries':len(versions),'history_format_valid':valid,'duplicate_history_versions':sorted({v for v in versions if versions.count(v)>1}),'unknown_history_versions':sorted(set(versions)-{x.split('_',1)[0] for x in originals}-{x.split('_',1)[0] for x in proposed}), 'history_comparison_only':True})
        if not valid:problems.append('invalid version format in history export')
        if result['duplicate_history_versions']:problems.append('duplicate versions in history export')
        if result['unknown_history_versions']:problems.append('unknown migration versions in history export')
    print(json.dumps(result,indent=2))
    return 0 if not problems else 2
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--history',help='Read-only CSV or JSON export with migration versions');args=p.parse_args()
    sys.exit(run(args.history))
