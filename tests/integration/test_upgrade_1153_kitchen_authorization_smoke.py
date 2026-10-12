from pathlib import Path
SQL = (Path(__file__).resolve().parents[2] /
       'supabase/verification/kitchen_1153_authorization_smoke.sql').read_text()

def test_negative_fixture_and_permission_guard():
    assert "denied_employee_uuid" in SQL
    assert "gs_can_access('kitchen','can_edit')" in SQL
    assert "Invalid negative fixture" in SQL

def test_unexpected_errors_are_not_swallowed():
    assert "Unexpected error (not an authorization denial)" in SQL
    assert "Not authorized to update kitchen orders" in SQL
    assert "SECURITY REGRESSION" in SQL

def test_rollback_and_state_invariance():
    assert "BEGIN;" in SQL and "ROLLBACK;" in SQL
    assert "v_after IS DISTINCT FROM v_before" in SQL
    assert "SET LOCAL ROLE authenticated" in SQL
