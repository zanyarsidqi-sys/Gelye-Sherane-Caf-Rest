from pathlib import Path
SRC = Path(__file__).resolve().parents[2] / 'lib/sections/products_inventory.dart'
s = SRC.read_text()
def test_auth_listener_is_cancelled():
    assert 'onAuthStateChange.listen' in s
    assert '_authSubscription.cancel()' in s
def test_stale_inventory_response_is_rejected():
    assert 'requestedEmployeeId' in s
    assert "auth.currentUser?.id != requestedEmployeeId" in s
def test_both_inventory_views_guard_session():
    assert s.count('auth.currentUser?.id != _inventoryEmployeeId') >= 2
def test_refresh_binds_new_session():
    assert '_inventoryEmployeeId = Supabase.instance.client.auth.currentUser?.id;' in s
