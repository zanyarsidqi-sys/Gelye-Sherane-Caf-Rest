from pathlib import Path

def test_upgrade_1351_contract():
    root = Path(__file__).resolve().parents[2]
    sql = (root / "supabase/migrations/20261012_1351_standing_cash_settlement_blockers.sql").read_text()
    for required in ("security definer", "set search_path = ''", "gs_can_access", "'collection_authorized',false", "revoke all on function", "grant execute on function"):
        assert required in sql
