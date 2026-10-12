#!/usr/bin/env python3
"""Static source checks plus synthetic endpoint rejection tests; no network."""
import pathlib,re,sys
root=pathlib.Path(__file__).resolve().parents[1]
main=(root/'lib/main.dart').read_text()
checks={
 'expected project ref is build-time constant': "String.fromEnvironment('SUPABASE_EXPECTED_PROJECT_REF')" in main,
 'strict project host comparison': "parsedUrl.host == '$expectedProjectRef.supabase.co'" in main,
 'HTTPS required': "parsedUrl.scheme == 'https'" in main,
 'credentials not included in errors': 'supabaseKey' not in main.split('runApp(')[1].split('return;')[0],
 'no hardcoded project URL': not re.search(r'https://[a-z0-9-]+\.supabase\.co',main),
 'service role not in startup': 'service_role' not in main.lower(),
}
from urllib.parse import urlsplit
valid_ref='abcdefghijklmnopqrst'
def allowed(url,expected):
 try:
  u=urlsplit(url)
  return bool(re.fullmatch(r'[a-z]{20}',expected)) and u.scheme=='https' and u.hostname==expected+'.supabase.co' and u.port in (None,443) and not u.username and not u.password and u.path in ('','/') and not u.query and not u.fragment
 except ValueError:return False
cases=[('matching',f'https://{valid_ref}.supabase.co',valid_ref,True),('cross-project',f'https://{valid_ref}.supabase.co','bcdefghijklmnopqrstu',False),('http',f'http://{valid_ref}.supabase.co',valid_ref,False),('subdomain',f'https://{valid_ref}.supabase.co.evil.test',valid_ref,False),('credentials',f'https://user@{valid_ref}.supabase.co',valid_ref,False),('query',f'https://{valid_ref}.supabase.co/?x=1',valid_ref,False),('missing-ref',f'https://{valid_ref}.supabase.co','',False)]
for name,url,ref,want in cases:checks['synthetic '+name]=allowed(url,ref)==want
for label,ok in checks.items():print(('PASS' if ok else 'FAIL')+': '+label)
sys.exit(0 if all(checks.values()) else 1)
