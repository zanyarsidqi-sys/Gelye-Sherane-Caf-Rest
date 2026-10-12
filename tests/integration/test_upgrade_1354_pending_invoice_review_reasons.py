from pathlib import Path

def test_review_reasons():
    s=Path(__file__).resolve().parents[2].joinpath('supabase/migrations/20261012_1354_pending_invoice_review_reasons.sql').read_text()
    for token in ('review_reason_codes','review_reason_count','UNKNOWN_PAYMENT_STATUS','INVALID_INVOICE_TOTAL','SOURCE_COUNT_MISMATCH','INVALID_INVOICE_LINES','INVALID_CASH_SETTLEMENT','UNPAID_WITH_CASH_SETTLEMENT','PAID_CASH_RECONCILIATION_FAILED',"'collection_authorized',false",'gs_can_access','revoke all','grant execute'):
        assert token in s, token
    assert 'insert into' not in s.lower() and 'update public.' not in s.lower()
