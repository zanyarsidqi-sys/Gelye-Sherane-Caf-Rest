from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
SQL = (ROOT / 'supabase/migrations/20261010_571_replacement_reconciliation_guidance.sql').read_text()
UI = (ROOT / 'lib/sections/table_orders.dart').read_text()

def test_read_only_existing_reconciliation():
    assert 'stable security invoker' in SQL
    assert 'public.gs_table_replacement_reconciliation(p_request_id)' in SQL
    assert 'update public.' not in SQL.lower() and 'insert into' not in SQL.lower()

def test_missing_receipt_not_safe_to_retry():
    assert "'review_state','unconfirmed'" in SQL
    assert 'Do not retry automatically' in SQL

def test_never_claims_acknowledgment_or_financial_settlement():
    assert "'kitchen_acknowledged',null,'financially_reconciled',null" in SQL
    assert 'financial settlement remain unverified' in SQL

def test_ui_uses_guidance():
    assert "'gs_table_replacement_reconciliation_guidance'" in UI
    assert "response['staff_guidance']" in UI
