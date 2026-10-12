from pathlib import Path
SQL = (Path(__file__).resolve().parents[2] / 'supabase/migrations/20261010_557_replacement_input_consistency.sql').read_text()
def test_both_entrypoints_validate_ids_and_prices():
    assert SQL.count("raise exception 'Invalid replacement request'") == 2
    assert SQL.count('p_expected_unit_price_iqd < 0') == 2
def test_both_entrypoints_reject_invalid_quantities():
    assert 'v_qty is null or v_qty <= 0' in SQL
    assert 'v_quantity is null or v_quantity <= 0' in SQL
def test_preserve_kitchen_and_financial_controls():
    assert SQL.count('d.acknowledged_at is not null') == 2
    assert 'p_confirmed_new_unit_price_iqd <> v_new_price' in SQL
    assert 'gs_item_payment_allocations' in SQL
