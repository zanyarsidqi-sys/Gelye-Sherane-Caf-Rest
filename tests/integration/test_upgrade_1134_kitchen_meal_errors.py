from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / "lib/shared/kitchen_scheduled_motel_meals_panel.dart"

def test_kitchen_meal_errors_are_not_exposed():
    code = SOURCE.read_text()
    assert "Unable to update meal: $error" not in code
    assert "Unable to update meal. Check permission and current status." in code

def test_kitchen_uses_authorized_backend_transition():
    code = SOURCE.read_text()
    assert "gs_kitchen_progress_motel_scheduled_meal" in code
    assert "_busy.contains(id)" in code
