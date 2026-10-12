from pathlib import Path
s = (Path(__file__).resolve().parents[2] / 'lib/sections/products_inventory.dart').read_text()

def test_history_request_cached_before_dialog():
    assert "final historyRequest = Supabase.instance.client.rpc('gs_inventory_history'" in s
    assert s.index('final historyRequest =') < s.index('await showDialog<void>(')

def test_future_builder_reuses_request():
    assert 'future: historyRequest,' in s
    assert s.count("rpc('gs_inventory_history'") == 1

def test_session_checked_before_dialog_and_results():
    assert 'if (!mounted || Supabase.instance.client.auth.currentUser?.id != historyEmployeeId) return;' in s
    assert 'if (Supabase.instance.client.auth.currentUser?.id != historyEmployeeId)' in s
