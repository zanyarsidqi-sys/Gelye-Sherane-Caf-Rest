from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
SQL = (ROOT / 'supabase/migrations/20261010_573_replacement_dispatch_completeness.sql').read_text()
UI = (ROOT / 'lib/sections/table_orders.dart').read_text()

def test_exact_revision_no_truncated_board():
    assert 'd.revision_id=v_revision' in SQL
    assert 'gs_staff_kitchen_revision_reconciliation' not in SQL

def test_every_dispatch_checked_with_audit():
    assert "d.destination_type='kitchen_revision'" in SQL
    assert 'duplicate_audit' in SQL and 'timestamp_mismatch' in SQL
    assert 'kitchen_receipt_dispatch_count' in SQL

def test_safe_staff_guidance():
    assert 'do not resend automatically' in SQL
    assert "response['kitchen_receipt_guidance']" in UI
    assert "response['kitchen_receipt_duplicate_audit_count']" in UI
