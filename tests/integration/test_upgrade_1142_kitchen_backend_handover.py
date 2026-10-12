from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SQL = (ROOT / 'supabase/migrations/20261010_1142_kitchen_served_item_integrity.sql').read_text()


def test_backend_authorizes_employee_and_locks_order():
    assert "gs_can_access('kitchen', 'can_edit')" in SQL
    assert 'for update' in SQL.lower()
    assert "v_current = 'ready' and p_next_status = 'served'" in SQL


def test_served_requires_nonempty_valid_items():
    assert "if p_next_status = 'served'" in SQL
    assert 'if v_item_count = 0 then' in SQL
    assert 'quantity <= 0' in SQL
    assert 'line_total_iqd::numeric <> quantity::numeric * unit_price_iqd::numeric' in SQL


def test_rpc_access_remains_authenticated_only():
    assert 'revoke all on function public.gs_update_kitchen_status(bigint,text) from public;' in SQL
    assert 'grant execute on function public.gs_update_kitchen_status(bigint,text) to authenticated;' in SQL
