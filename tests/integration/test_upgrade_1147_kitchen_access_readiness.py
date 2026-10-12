from pathlib import Path
SQL = (Path(__file__).resolve().parents[2] / 'supabase/verification/kitchen_1147_access_readiness.sql').read_text().lower()
def test_read_only():
    assert 'with checks(' in SQL and 'select check_name, passed, details' in SQL
    for statement in ('create table ', 'drop table ', 'insert into ', 'update public.', 'delete from '):
        assert statement not in SQL
def test_permissions_covered():
    for marker in ("has_function_privilege('authenticated'", "has_function_privilege('anon'", 'aclexplode', 'gs_guard_served_order_items', 't.tgenabled'):
        assert marker in SQL
def test_staging_review_required():
    assert 'all rows must show passed = true' in SQL and 'after migrations 1142-1144' in SQL
