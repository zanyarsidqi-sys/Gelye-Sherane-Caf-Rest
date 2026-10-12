from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'supabase/migrations/20261012_1497_release_publish_evidence_binding.sql').read_text()
assert 'create or replace function public.gs_app_release_publish_gate()' in s
assert 'gs_app_release_verified' in s
assert "v_release.checks->v_key" in s
assert "new.request_payload->'checks'->v_key" in s
assert "new.before_state->>'id'" in s
assert "new.after_state->'release'->>'version'" in s
assert 'deployment_verified flag' in s
assert 'revoke all on function' in s
print('PASS: release publish review-evidence binding source contract')
