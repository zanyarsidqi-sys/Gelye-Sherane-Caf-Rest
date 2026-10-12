from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SQL = (ROOT / 'supabase/verification/kitchen_1152_transition_smoke.sql').read_text()

def test_smoke_checks_real_rpc_sequence():
    assert SQL.count('PERFORM public.gs_update_kitchen_status') == 4
    assert "'preparing'" in SQL and "'ready'" in SQL and "'served'" in SQL

def test_smoke_rolls_back_and_checks_guard():
    assert 'BEGIN;' in SQL and 'ROLLBACK;' in SQL
    assert 'DELETE FROM public.gs_order_items' in SQL
    assert 'Regression: served items were deleted' in SQL

def test_smoke_requires_explicit_staging_fixture():
    assert 'test_order_id' in SQL and 'test_employee_uuid' in SQL
    assert 'DO NOT run in production' in SQL
