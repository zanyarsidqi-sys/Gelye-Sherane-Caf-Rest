from pathlib import Path
SRC = (Path(__file__).resolve().parents[2] / 'lib/shared/live_kitchen_panel.dart').read_text()

def test_refresh_invalidates_pending_confirmation():
    block = SRC.split('void _refresh() => setState(() {', 1)[1].split('});', 1)[0]
    assert '_confirmationToken++;' in block
    assert '_confirmingId = null;' in block
    assert '_loadGeneration++;' in block

def test_old_confirmation_cannot_advance_after_refresh():
    block = SRC.split('Future<void> _confirmAndAdvance(', 1)[1].split('Future<void> _advance(', 1)[0]
    assert 'confirmationToken != _confirmationToken' in block
    assert 'queueGeneration != _loadGeneration' in block
    assert 'await _advance(id, next' in block
