from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
main = (root / 'lib' / 'main.dart').read_text()
checks = {
    'URL uses build-time environment': "String.fromEnvironment('SUPABASE_URL')" in main,
    'Public key uses build-time environment': "String.fromEnvironment('SUPABASE_ANON_KEY')" in main,
    'No hardcoded Supabase project URL in startup': re.search(r'https://[a-z0-9-]+\.supabase\.co', main) is None,
    'No service role key in startup': 'service_role' not in main.lower(),
    'Migrations directory exists': (root / 'supabase' / 'migrations').is_dir(),
}
for name, ok in checks.items():
    print(('PASS' if ok else 'FAIL') + ': ' + name)
if not all(checks.values()):
    raise SystemExit(1)
print('Static checks only. Remote database security remains unverified.')
