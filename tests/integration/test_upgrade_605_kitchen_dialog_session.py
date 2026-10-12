from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / 'lib/shared/live_kitchen_panel.dart'

def test_capture_session_before_dialog():
    s = SOURCE.read_text()
    start = s.index('Future<void> _confirmAndAdvance')
    dialog = s.index('showDialog<bool>', start)
    assert s.index('final employeeId =', start) < dialog
    assert s.index('final queueGeneration =', start) < dialog

def test_recheck_session_after_dialog():
    s = SOURCE.read_text()
    start = s.index('if (!mounted || confirmed != true) return;')
    end = s.index('await _advance(id, next', start)
    assert '_isCurrentEmployee(employeeId)' in s[start:end]
    assert 'queueGeneration != _loadGeneration' in s[start:end]

def test_update_requires_original_session():
    s = SOURCE.read_text()
    start = s.index('Future<void> _advance(')
    end = s.index(".rpc('gs_update_kitchen_status'", start)
    assert 'required String? expectedEmployeeId' in s[start:end]
    assert 'required int expectedQueueGeneration' in s[start:end]
    assert 'employeeId != expectedEmployeeId' in s[start:end]
    assert 'expectedQueueGeneration != _loadGeneration' in s[start:end]
