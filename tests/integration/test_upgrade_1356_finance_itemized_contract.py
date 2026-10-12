from pathlib import Path

def test_finance_itemized_contract():
    root = Path(__file__).resolve().parents[2]
    sql = (root / 'supabase/migrations/20261012_1356_finance_itemized_delivery_detail.sql').read_text()
    assert 'gs_finance_itemized_order_detail' in sql
    assert 'gs_finance_motel_request_detail' in sql
    assert "gs_can_access('payments_management','can_view')" in sql
    assert 'unit_price_iqd' in sql and 'line_total_iqd' in sql
    assert 'delivery_employee_id' in sql and 'room_number' in sql
    assert 'revoke all on function' in sql
    assert 'settlement_verified' in sql
