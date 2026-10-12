from pathlib import Path

SQL = (Path(__file__).resolve().parents[2] / "supabase/migrations/20261010_575_replacement_revision_full_identity.sql").read_text()

def test_revision_order_is_checked():
    assert "v_order is distinct from (v->'result'->>'order_id')::bigint" in SQL

def test_financial_snapshot_checked():
    assert "v_revision_price is distinct from" in SQL
    assert "v_revision_qty is distinct from" in SQL

def test_actor_and_type_checked():
    assert "v_revision_actor is distinct from auth.uid()" in SQL
    assert "v_revision_type is distinct from 'price_adjustment'" in SQL

def test_read_only_and_permission_protected():
    assert "public.gs_can_access('kitchen','can_view')" in SQL
    assert 'stable security definer' in SQL
    assert 'grant execute on function' in SQL
