from pathlib import Path
root=Path(__file__).resolve().parents[1]
s=(root/'supabase/migrations/20261012_1495_release_publish_gate_hardening.sql').read_text()
assert "jsonb_typeof(p_checks)='object'" in s
for key in ('deployment_verified','smoke','permissions','backend','backup','artifact'):
 assert f"(p_checks->'{key}') = 'true'::jsonb" in s
assert "v_release.status <> 'published'" in s
assert "v_release.platform <> 'web'" in s
assert "v_release.channel <> 'stable'" in s
assert "(new.request_payload->>'id') is distinct from new.release_id::text" in s
assert 'raise exception' in s and 'commit;' in s
print('Strict publication event gate contract: PASS')
