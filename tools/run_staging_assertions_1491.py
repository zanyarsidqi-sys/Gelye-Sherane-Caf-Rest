#!/usr/bin/env python3
"""Run staging read-only prerequisites using installed psql and STAGING_DATABASE_URL.
Never use production credentials. Requires explicitly supplied --staging flag.
"""
import argparse, os, subprocess, sys
from pathlib import Path
p=argparse.ArgumentParser(); p.add_argument('--staging',action='store_true'); a=p.parse_args()
if not a.staging: sys.exit('Explicit --staging confirmation required')
url=os.environ.get('STAGING_DATABASE_URL','')
if not url: sys.exit('STAGING_DATABASE_URL is required')
if os.environ.get('GS_ENVIRONMENT')!='staging': sys.exit('GS_ENVIRONMENT=staging is required')
script=Path(__file__).resolve().parents[1]/'supabase'/'diagnostics'/'staging_assertions_1491.sql'
r=subprocess.run(['psql',url,'-X','-v','ON_ERROR_STOP=1','-f',str(script)],check=False)
sys.exit(r.returncode)
