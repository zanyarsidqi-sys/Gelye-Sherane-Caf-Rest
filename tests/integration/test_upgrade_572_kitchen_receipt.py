from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
SQL = (ROOT/'supabase/migrations/20261010_572_replacement_kitchen_receipt_status.sql').read_text()
UI = (ROOT/'lib/sections/table_orders.dart').read_text()

def test_exact_revision_filter():
    assert 'where k.revision_id=v_revision' in SQL
    assert 'gs_staff_kitchen_revision_reconciliation(v_order)' in SQL

def test_permission_and_no_mutation():
    assert "gs_can_access('kitchen','can_view')" in SQL
    assert "gs_can_access('table_orders','can_view')" in SQL
    assert 'update public.' not in SQL.lower()

def test_ui_receipt_status():
    assert "'gs_table_replacement_kitchen_receipt_status'" in UI
    assert "response['kitchen_receipt_state']" in UI
