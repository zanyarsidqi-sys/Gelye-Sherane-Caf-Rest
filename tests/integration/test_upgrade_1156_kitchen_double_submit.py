from pathlib import Path
SRC=(Path(__file__).resolve().parents[2]/'lib/shared/live_kitchen_panel.dart').read_text()

def test_confirmation_has_single_flight_guard():
    assert "if (_confirmingId != null || _busyId != null) return;" in SRC
    assert "_confirmingId = id;" in SRC
    assert "if (_confirmingId == id) _confirmingId = null;" in SRC

def test_session_change_clears_confirmation_lock():
    segment=SRC[SRC.index('onAuthStateChange.listen'):SRC.index('String _query')]
    assert '_confirmingId = null;' in segment

def test_status_rpc_is_still_authoritative():
    assert "rpc('gs_update_kitchen_status'" in SRC
    assert "_advance(id, next, expectedEmployeeId:" in SRC
