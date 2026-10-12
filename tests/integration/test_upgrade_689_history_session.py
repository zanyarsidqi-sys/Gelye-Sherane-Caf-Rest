from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / 'lib/sections/products_inventory.dart'

def test_dialog_observes_auth_changes():
    text = SOURCE.read_text()
    dialog = text.split('Future<void> _history(', 1)[1].split('Widget build(', 1)[0]
    assert 'StreamBuilder<AuthState>(' in dialog
    assert 'stream: Supabase.instance.client.auth.onAuthStateChange' in dialog
    assert 'Employee changed. Close and reopen history.' in dialog

def test_history_request_created_once():
    text = SOURCE.read_text()
    dialog = text.split('Future<void> _history(', 1)[1].split('Widget build(', 1)[0]
    assert dialog.index("final historyRequest =") < dialog.index('await showDialog<void>')
    assert 'future: historyRequest' in dialog

def test_session_checked_before_history_render():
    text = SOURCE.read_text()
    dialog = text.split('Future<void> _history(', 1)[1].split('Widget build(', 1)[0]
    assert dialog.count('currentUser?.id != historyEmployeeId') >= 2
