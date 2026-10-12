from pathlib import Path
SRC = (Path(__file__).resolve().parents[2] / 'lib/shared/live_kitchen_panel.dart').read_text()

def test_resume_refreshes_kitchen_queue():
    assert 'with WidgetsBindingObserver' in SRC
    assert 'WidgetsBinding.instance.addObserver(this)' in SRC
    assert 'state == AppLifecycleState.resumed && mounted' in SRC
    assert '_refresh();' in SRC.split('void didChangeAppLifecycleState',1)[1].split('void dispose()',1)[0]

def test_observer_removed_on_dispose():
    assert 'WidgetsBinding.instance.removeObserver(this)' in SRC

def test_resume_refresh_invalidates_old_confirmations():
    block = SRC.split('void _refresh()',1)[1].split('Future<void> _confirmAndAdvance',1)[0]
    assert '_confirmationToken++' in block
    assert '_itemRequests.clear()' in block
