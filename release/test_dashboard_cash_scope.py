from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
cash_sql = (ROOT / "supabase/migrations/20261013_1499_dashboard_cash_scope.sql").read_text()
preferences_sql = (
    ROOT / "supabase/migrations/20261013_1498_dashboard_preferences_revision_conflicts.sql"
).read_text()

assert "if v_cash and (v_orders or v_motel)" in cash_sql
assert "join public.gs_orders o on o.id = p.order_id" in cash_sql
assert "((not o.is_motel and v_orders) or (o.is_motel and v_motel))" in cash_sql
assert "p_expected_revision <> v_revision" in preferences_sql
assert "using errcode = '40001'" in preferences_sql
assert "for update" in preferences_sql.lower()
assert "revoke all on public.gs_dashboard_preferences from public, anon, authenticated" in preferences_sql
print("Dashboard permission-scoped aggregates and preference revision guards: PASS")
