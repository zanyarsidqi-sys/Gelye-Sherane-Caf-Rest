#!/usr/bin/env python3
"""Phase 1 Step 14: safe, read-only database execution readiness check.
No connection to any database is made. Requires a separate disposable Supabase environment
for actual migration execution; never target a live or existing database.
"""
import json, pathlib, subprocess, sys, shutil, tempfile
root=pathlib.Path(__file__).resolve().parents[1]
prepare=root/'tools'/'phase1_step13_prepare_isolated_migrations.py'
result={'step':14,'mode':'offline_only','postgres_available':bool(shutil.which('psql')),'docker_available':bool(shutil.which('docker')),'supabase_cli_available':bool(shutil.which('supabase')),'database_executed':False,'source_migrations_modified':False}
with tempfile.TemporaryDirectory(prefix='phase1_step14_') as tmp:
    p=subprocess.run([sys.executable,str(prepare),'--output',str(pathlib.Path(tmp)/'staging')],capture_output=True,text=True)
    result['staging_exit_code']=p.returncode
    result['staging_output']=(p.stdout+p.stderr).strip()
    if p.returncode==0:
        files=list((pathlib.Path(tmp)/'staging'/'supabase'/'migrations').glob('*.sql'))
        result['staged_migration_count']=len(files)
        result['unique_staged_filenames']=len({f.name for f in files})==len(files)
result['ready_for_live_execution']=False
print(json.dumps(result,indent=2))
if result['staging_exit_code'] or not result.get('unique_staged_filenames'):sys.exit(1)
