from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'web/push_client.js').read_text()
assert '/^[a-z0-9]{20}\\.supabase\\.co$/' in s
assert '/^[a-z]{20}\\.supabase\\.co$/' not in s
print('Supabase alphanumeric project reference validation: PASS')
