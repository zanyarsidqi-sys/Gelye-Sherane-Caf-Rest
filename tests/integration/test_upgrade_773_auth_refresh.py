from pathlib import Path

SOURCE = (Path(__file__).resolve().parents[2] / 'lib/sections/products_inventory.dart').read_text()


def test_auth_listener_uses_current_authenticated_user():
    listener = SOURCE.split('onAuthStateChange.listen((event) {', 1)[1].split('});', 1)[0]
    assert 'Supabase.instance.client.auth.currentUser?.id' in listener
    assert 'event.session?.user.id' not in listener


def test_refresh_still_checks_employee_identity():
    assert 'currentId == _inventoryEmployeeId' in SOURCE
    assert '_inventoryEmployeeId = Supabase.instance.client.auth.currentUser?.id;' in SOURCE


def test_stock_loading_guards_employee_switch():
    assert 'requestedEmployeeId' in SOURCE
    assert 'currentUser?.id != requestedEmployeeId' in SOURCE
