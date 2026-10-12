from pathlib import Path
root = Path(__file__).resolve().parents[2]
sql = (root/'supabase/migrations/20261010_566_replacement_request_integrity.sql').read_text()
dart = (root/'lib/sections/table_orders.dart').read_text()
def test_receipts_immutable():
    assert 'before update or delete' in sql.lower()
    assert 'raise exception' in sql.lower()
def test_status_is_private_and_not_retry_safe():
    assert "'retry_safe',false" in sql
    assert 'actor_id=auth.uid()' in sql
    assert 'to authenticated' in sql
def test_client_uses_scoped_status():
    assert "client.rpc('gs_table_replacement_request_status'" in dart
    assert "recorded['status'] == 'committed'" in dart
