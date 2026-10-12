from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
SQL = (ROOT / 'supabase/migrations/20261010_568_replacement_receipt_history.sql').read_text()
UI = (ROOT / 'lib/sections/table_orders.dart').read_text()

def test_receipts_are_actor_scoped():
    assert 'where actor_id = auth.uid()' in SQL
    assert "gs_can_access('table_orders','can_view')" in SQL

def test_history_is_bounded_and_permissioned():
    assert 'p_limit > 50' in SQL
    assert 'limit p_limit' in SQL
    assert 'grant execute on function public.gs_table_replacement_receipt_history(integer) to authenticated' in SQL

def test_history_available_in_staff_ui_without_retry():
    assert "'gs_table_replacement_receipt_history'" in UI
    assert 'My replacement receipts (all devices)' in UI
    assert 'does not prove an outstanding request is safe to repeat' in UI
