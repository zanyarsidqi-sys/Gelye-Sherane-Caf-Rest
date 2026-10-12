from pathlib import Path
S = (Path(__file__).resolve().parents[2] / "lib/shared/live_kitchen_panel.dart").read_text()

def test_busy_operation_uses_unique_token():
    assert "final operationToken = ++_busyOperationToken;" in S
    assert "_busyOperationToken == operationToken" in S

def test_employee_switch_invalidates_inflight_operation():
    assert "_busyId = null;\n        _busyOperationToken++;" in S

def test_dispose_invalidates_inflight_operation():
    assert "_confirmationToken++;\n    _busyOperationToken++;\n    super.dispose();" in S
