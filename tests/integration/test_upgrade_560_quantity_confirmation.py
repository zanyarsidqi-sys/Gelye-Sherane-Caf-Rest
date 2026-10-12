from pathlib import Path
root=Path(__file__).resolve().parents[2]
sql=(root/'supabase/migrations/20261010_560_replacement_quantity_confirmation.sql').read_text()
dart=(root/'lib/sections/table_orders.dart').read_text()
def test_expected_quantity_checked_under_locks():
 assert 'p_expected_quantity integer' in sql
 assert 'for update' in sql
 assert 'v_actual_quantity is distinct from p_expected_quantity' in sql
def test_old_endpoint_revoked_and_new_granted():
 assert 'bigint,bigint,bigint,bigint,text,bigint) from public,anon,authenticated' in sql
 assert 'bigint,bigint,bigint,bigint,text,bigint,integer) to authenticated' in sql
def test_ui_passes_quoted_quantity():
 assert "'p_expected_quantity': quotedQuantity" in dart
