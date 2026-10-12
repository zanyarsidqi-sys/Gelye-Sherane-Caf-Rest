from pathlib import Path

def test_upgrade_1355_finance_triage_contract():
    sql = Path(__file__).resolve().parents[2] / 'supabase/migrations/20261012_1355_pending_invoice_finance_triage.sql'
    body = sql.read_text()
    assert 'gs_pending_payment_motel_invoice_integrity(p_invoice_id)' in body
    assert "'collection_authorized',false" in body
    assert "'settlement_confirmed',false" in body
    assert 'revoke all on function' in body
    assert 'grant execute on function' in body
    assert 'insert into' not in body.lower()
    assert 'update public.' not in body.lower()
    assert 'delete from' not in body.lower()
