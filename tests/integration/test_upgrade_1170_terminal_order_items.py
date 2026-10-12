from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
MIGRATION = (ROOT / 'supabase/migrations/20261011_1170_kitchen_terminal_order_item_immutability.sql').read_text()
PRIOR = (ROOT / 'supabase/migrations/20261010_1144_kitchen_served_item_immutability.sql').read_text()

def test_terminal_orders_immutable():
    assert "v_status in ('served', 'cancelled')" in MIGRATION
    assert 'where id = v_order_id for update' in MIGRATION
    assert 'Moving order items between orders is not permitted' in MIGRATION

def test_existing_trigger_remains_connected():
    assert 'create trigger gs_guard_served_order_items' in PRIOR
    assert 'execute function public.gs_guard_served_order_items()' in PRIOR
    assert 'create or replace function public.gs_guard_served_order_items()' in MIGRATION

def test_no_client_execute_grants():
    assert 'from public, anon, authenticated' in MIGRATION
