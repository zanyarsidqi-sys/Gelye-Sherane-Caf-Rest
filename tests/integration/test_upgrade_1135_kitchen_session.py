from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / "lib/shared/kitchen_scheduled_motel_meals_panel.dart"

def test_session_change_clears_previous_employee_meals():
    code = SOURCE.read_text()
    assert "onAuthStateChange.listen" in code
    assert "currentId == _employeeId" in code
    assert "_sessionRevision++" in code
    assert "_future = currentId == null" in code

def test_async_action_does_not_refresh_or_report_after_employee_switch():
    code = SOURCE.read_text()
    assert "revisionAtStart = _sessionRevision" in code
    assert code.count("_sessionRevision == revisionAtStart") >= 3

def test_listener_cleanup_and_signed_out_view():
    code = SOURCE.read_text()
    assert "_authSubscription.cancel();" in code
    assert "Sign in to view scheduled motel meals." in code
