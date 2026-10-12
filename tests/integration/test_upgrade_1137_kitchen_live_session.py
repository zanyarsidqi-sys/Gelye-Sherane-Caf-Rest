from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / 'lib/shared/live_kitchen_panel.dart'

def test_auth_subscription_cleans_up():
    code = SOURCE.read_text()
    assert 'onAuthStateChange.listen' in code
    assert '_authSubscription?.cancel()' in code

def test_employee_switch_clears_sensitive_caches():
    code = SOURCE.read_text()
    assert '_sessionEmployeeId = currentId;' in code
    assert '_itemRequests.clear();' in code
    assert '_loadedUserId = null;' in code
    assert '_busyEmployeeId = null;' in code

def test_queue_hidden_for_incorrect_session():
    code = SOURCE.read_text()
    assert 'if (_loadedUserId == null || !_isCurrentEmployee(_loadedUserId))' in code
    assert "SelectableText('${snapshot.error}')" not in code
