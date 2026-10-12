from pathlib import Path

SQL = (Path(__file__).resolve().parents[2] / "supabase/migrations/20261010_1143_kitchen_served_item_row_locks.sql").read_text().lower()


def test_item_rows_locked_before_status_change():
    assert "for update" in SQL.split("locked_items;")[0]
    assert SQL.index("locked_items;") < SQL.index("update public.gs_orders set status")


def test_rejects_empty_and_invalid_item_sets():
    assert "v_item_count = 0" in SQL
    assert "v_invalid_count > 0" in SQL
    assert "quantity::numeric * unit_price_iqd::numeric" in SQL


def test_permission_and_execute_scope():
    assert "public.gs_can_access('kitchen', 'can_edit')" in SQL
    assert "from public, anon" in SQL
    assert "to authenticated" in SQL
