from pathlib import Path
SOURCE = Path(__file__).resolve().parents[2] / "lib/shared/kitchen_motel_food_queue_panel.dart"

def test_employee_change_invalidates_visible_queue():
    code = SOURCE.read_text()
    assert "onAuthStateChange.listen" in code
    assert "currentId == _employeeId" in code
    assert "_sessionRevision++" in code
    assert "_requests = currentId == null" in code

def test_inflight_actions_cannot_update_new_employee_ui():
    code = SOURCE.read_text()
    assert "employeeAtStart = _employeeId" in code
    assert code.count("_sessionRevision == revisionAtStart") == 3
    assert "_saving = false;" in code

def test_signed_out_view_and_cleanup():
    code = SOURCE.read_text()
    assert "_authSubscription.cancel();" in code
    assert "Sign in to view motel food requests." in code
    assert "order['id'] == null" in code
