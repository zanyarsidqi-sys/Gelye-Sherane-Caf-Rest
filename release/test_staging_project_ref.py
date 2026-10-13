from pathlib import Path
root=Path(__file__).resolve().parents[1]
workflow=(root/'.github/workflows/pages.yml').read_text()
client=(root/'web/push_client.js').read_text()
app=(root/'lib/main.dart').read_text()
assert '^[a-z0-9]{20}$' in workflow
assert r'/^[a-z0-9]{20}\.supabase\.co$/' in client
assert "RegExp(r'^[a-z0-9]{20}$')" in app
assert 'SUPABASE_EXPECTED_PROJECT_REF' in workflow
print('PASS Flutter app, staging workflow and browser push agree on project ref format')
