from pathlib import Path
SQL = (Path(__file__).resolve().parents[2] / 'supabase/migrations/20261010_574_replacement_revision_identity.sql').read_text()

def test_receipt_owned_reconciliation_required():
    assert 'gs_table_replacement_reconciliation_guidance(p_request_id)' in SQL
    assert "gs_can_access('kitchen','can_view')" in SQL

def test_revision_identity_bound_to_receipt():
    assert 'e.order_item_id,e.after_snapshot' in SQL
    assert "v_revision_item is distinct from (v->'result'->>'order_item_id')::bigint" in SQL
    assert "v_revision_product is distinct from v->'result'->>'product_id'" in SQL

def test_mismatch_blocks_dispatch_claims():
    assert "'kitchen_receipt_state','revision_receipt_mismatch'" in SQL
    assert "'kitchen_acknowledged',false" in SQL
    assert SQL.index('revision_receipt_mismatch') < SQL.index('with receipts as')

def test_no_mutation_or_retry():
    assert 'insert into public.gs_order_revision_dispatch' not in SQL.lower()
    assert 'do not resend automatically' in SQL
