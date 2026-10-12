from pathlib import Path

SQL = (Path(__file__).resolve().parents[2] / 'supabase/migrations/20261010_556_missing_kitchen_dispatch_guard.sql').read_text()

def test_both_rpcs_fail_closed_on_missing_dispatch():
    assert SQL.count('and not exists (') == 2
    assert SQL.count('d.acknowledged_at is not null') == 2

def test_existing_price_and_permission_guards_retained():
    assert 'p_confirmed_new_unit_price_iqd <> v_new_price' in SQL
    assert SQL.count("gs_can_access('table_orders','can_edit')") == 2
    assert 'for update' in SQL.lower()

def test_replacement_dispatch_still_created():
    assert "(v_event,'kitchen_revision','order:'||v_order_id::text)" in SQL
