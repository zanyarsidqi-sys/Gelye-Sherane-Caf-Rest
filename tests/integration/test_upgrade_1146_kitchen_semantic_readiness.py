from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
SQL = (ROOT / "supabase/verification/kitchen_1146_semantic_readiness.sql").read_text()

def test_read_only_and_six_checks():
    assert SQL.count("union all select") == 5
    assert "select check_name, passed, details" in SQL
    assert "create or replace" not in SQL.lower()

def test_checks_deployed_functions_and_trigger():
    assert "pg_get_functiondef" in SQL
    assert "pg_trigger" in SQL
    for fragment in ("v_item_count = 0", "locked_items", "line_total_iqd::numeric", "v_status =", "t.tgtype & 16"):
        assert fragment in SQL

def test_migration_has_required_semantics():
    status = (ROOT / "supabase/migrations/20261010_1143_kitchen_served_item_row_locks.sql").read_text()
    guard = (ROOT / "supabase/migrations/20261010_1144_kitchen_served_item_immutability.sql").read_text()
    assert "for update" in status.lower() and "locked_items" in status
    assert "v_item_count = 0" in status
    assert "line_total_iqd::numeric" in status
    assert "for update" in guard.lower() and "v_status = 'served'" in guard
