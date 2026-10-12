from pathlib import Path
root=Path(__file__).resolve().parents[1]
workflow=(root/'.github/workflows/iphone_web_staging.yml').read_text()
client=(root/'web/push_client.js').read_text()
assert '^[a-z0-9]{20}$' in workflow
assert r'/^[a-z0-9]{20}\.supabase\.co$/' in client
assert 'SUPABASE_EXPECTED_PROJECT_REF' in workflow
print('PASS staging project ref agrees with browser push validation')
