from pathlib import Path

SQL = (Path(__file__).resolve().parents[2] / 'supabase/migrations/20261010_1144_kitchen_served_item_immutability.sql').read_text().lower()


def test_all_mutations_guarded():
    assert 'before insert or update or delete' in SQL
    assert "v_status = 'served'" in SQL
    assert 'served order items cannot be modified' in SQL


def test_parent_locked_to_serialize_with_handover():
    assert 'where id = v_order_id for update' in SQL
    assert 'if not found then' in SQL


def test_order_reassignment_forbidden_and_trigger_idempotent():
    assert 'new.order_id is distinct from old.order_id' in SQL
    assert 'drop trigger if exists gs_guard_served_order_items' in SQL
    assert 'revoke all on function public.gs_guard_served_order_items() from public, anon, authenticated' in SQL
