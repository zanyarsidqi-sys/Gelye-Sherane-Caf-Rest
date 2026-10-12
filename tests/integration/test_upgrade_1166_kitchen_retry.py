from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'lib/shared/live_kitchen_panel.dart').read_text()

def test_error_screen_has_retry_action():
    start = SOURCE.index('if (snapshot.hasError) {')
    end = SOURCE.index('if (_loadedUserId == null', start)
    block = SOURCE[start:end]
    assert 'onPressed: _refresh' in block
    assert "Retry loading kitchen orders" in block

def test_retry_uses_session_invalidating_refresh():
    start = SOURCE.index('void _refresh() => setState')
    end = SOURCE.index('Future<void> _confirmAndAdvance', start)
    block = SOURCE[start:end]
    assert '_loadGeneration++' in block
    assert '_itemRequests.clear()' in block
    assert '_confirmationToken++' in block
