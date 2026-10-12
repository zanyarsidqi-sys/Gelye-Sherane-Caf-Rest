from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
SQL = (ROOT/'supabase/migrations/20261010_570_replacement_receipt_reconciliation.sql').read_text()
DART = (ROOT/'lib/sections/table_orders.dart').read_text()
def test_actor_scope_and_permission():
    assert 'r.actor_id=auth.uid()' in SQL
    assert "gs_can_access('table_orders','can_view')" in SQL

def test_no_mutation_and_no_retry():
    assert "'retry_safe',false" in SQL
    assert 'update public.' not in SQL.lower()
    assert 'delete from public.' not in SQL.lower()

def test_reconciliation_signals_and_ui():
    for field in ['revision_matches_receipt','kitchen_dispatch_recorded','current_item_matches_receipt','payment_records_present']:
        assert field in SQL and field in DART
    assert "'gs_table_replacement_reconciliation'" in DART
