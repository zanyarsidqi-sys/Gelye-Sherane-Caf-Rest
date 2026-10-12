#!/usr/bin/env python3
"""Verify and stage an immutable migration copy for a NEW disposable database.
Never connects to or changes any database. No production deployment.
"""
import argparse, hashlib, json, pathlib, shutil, sys

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--output', required=True, help='An empty directory outside project source')
    parser.add_argument('--verify-only', action='store_true')
    args=parser.parse_args()
    project=pathlib.Path(__file__).resolve().parents[1]
    plan=json.loads((project/'PHASE1_STEP11_FRESH_DB_RENUMBER_PLAN.json').read_text())
    source=project/'supabase'/'migrations'
    entries=plan['mapping']
    actual={p.name for p in source.glob('*.sql')}
    expected={x['original'] for x in entries}
    if actual != expected:
        raise RuntimeError(f'Migration inventory mismatch: missing={len(expected-actual)} unexpected={len(actual-expected)}')
    names=[x['proposed_for_fresh_database_only'] for x in entries]
    if len(set(names)) != len(names): raise RuntimeError('Duplicate proposed filenames')
    for item in entries:
        digest=hashlib.sha256((source/item['original']).read_bytes()).hexdigest()
        if digest != item['sha256']: raise RuntimeError('Source changed: '+item['original'])
    if args.verify_only:
        print(f'PASS: {len(entries)} immutable SQL sources, unique staged filenames; NO database accessed')
        return
    target=pathlib.Path(args.output).resolve()
    if target.exists() and any(target.iterdir()): raise RuntimeError('Output directory must be empty')
    target.mkdir(parents=True,exist_ok=True)
    staged=target/'supabase'/'migrations'
    staged.mkdir(parents=True)
    for item in entries: shutil.copyfile(source/item['original'],staged/item['proposed_for_fresh_database_only'])
    (target/'STAGING_ONLY_DO_NOT_USE_ON_EXISTING_DB.txt').write_text('Fresh disposable database only. No migration execution has been performed.\nReview dependencies and SQL before applying.\n')
    print(f'Staged {len(entries)} migration copies at {staged}; NO database accessed')
if __name__=='__main__':
    try: main()
    except Exception as exc:
        print(f'FAIL: {exc}',file=sys.stderr)
        sys.exit(1)
