from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
SQL = (ROOT / 'supabase/verification/kitchen_1145_readiness.sql').read_text()

def test_readiness_is_read_only():
    assert 'select check_name, passed, details' in SQL.lower()
    for forbidden in ('insert into ', 'update public.', 'delete from ', 'drop table ', 'create trigger '):
        assert forbidden not in SQL.lower()

def test_readiness_covers_required_objects():
    for marker in ('gs_orders', 'gs_order_items', 'gs_update_kitchen_status',
                   'gs_guard_served_order_items', 'pg_trigger'):
        assert marker in SQL

def test_readiness_checks_privileges():
    assert SQL.count('has_function_privilege') == 3
    assert "'anon'" in SQL and "'authenticated'" in SQL
