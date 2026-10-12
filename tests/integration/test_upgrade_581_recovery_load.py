from pathlib import Path

SRC = Path(__file__).resolve().parents[2] / 'lib/sections/table_orders.dart'
TEXT = SRC.read_text()

def test_latest_load_only():
    assert 'version != _recoveryLoadVersion' in TEXT
    assert 'final version = ++_recoveryLoadVersion' in TEXT

def test_logout_clears_visible_recovery():
    assert 'if (uid == null) {\n      if (mounted) setState(() => _pendingReplacement = null);' in TEXT

def test_inflight_replacement_protected():
    assert 'if (_editingInstructions && _pendingReplacement != null) return;' in TEXT
    assert '// Invalidate any earlier background recovery read before persisting.' in TEXT

def test_dispose_invalidates_load():
    assert '_boardRequestVersion++;\n    _recoveryLoadVersion++;' in TEXT
