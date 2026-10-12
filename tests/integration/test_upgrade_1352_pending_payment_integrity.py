from pathlib import Path

def test_pending_payment_contract():
    path = Path(__file__).resolve().parents[2] / 'supabase/migrations/20261012_1352_pending_payment_invoice_integrity.sql'
    sql = path.read_text()
    assert "security definer set search_path = ''" in sql
    assert "gs_can_access('payments_management','can_view')" in sql
    assert "gs_can_access('invoices_payments','can_view')" in sql
    assert "gs_can_access('motel_orders','can_view')" in sql
    assert "'collection_authorized',false" in sql
    assert 'insert into ' not in sql.lower()
    assert 'update public.' not in sql.lower()
    assert 'delete from ' not in sql.lower()
