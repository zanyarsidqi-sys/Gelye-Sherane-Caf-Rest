from pathlib import Path
s=(Path(__file__).resolve().parents[1]/'supabase/migrations/20261012_1496_release_announcement_idempotency.sql').read_text()
assert 'unique index if not exists gs_release_publish_once_per_release' in s
assert "where action = 'publish'" in s
assert "new.before_state->>'status'" in s and "'ready'" in s
assert "new.after_state->'release'->>'status'" in s and "'published'" in s
assert 'gs_app_release_verified' in s
print('Release transition idempotency static contract: PASS')
