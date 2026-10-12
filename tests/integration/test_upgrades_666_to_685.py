from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]

def test_upgrade_666():
    assert 'item.normalPrice > 1000000000' in (ROOT / 'lib/services/local_menu_preview.dart').read_text()

def test_upgrade_667():
    assert 'item.tourismPrice > 1000000000' in (ROOT / 'lib/services/local_menu_preview.dart').read_text()

def test_upgrade_668():
    assert 'p.barcode.trim() == item.barcode.trim()' in (ROOT / 'lib/services/local_menu_preview.dart').read_text()

def test_upgrade_669():
    assert 'item.barcode.trim() == barcode.trim()' in (ROOT / 'lib/services/local_menu_preview.dart').read_text()

def test_upgrade_670():
    assert 'item.name.trim().length > 200' in (ROOT / 'lib/services/local_menu_preview.dart').read_text()

def test_upgrade_671():
    assert 'item.barcode.trim().length > 100' in (ROOT / 'lib/services/local_menu_preview.dart').read_text()

def test_upgrade_672():
    assert '_name.text.trim().length > 200' in (ROOT / 'lib/sections/menu.dart').read_text()

def test_upgrade_673():
    assert '_barcode.text.trim().length > 100' in (ROOT / 'lib/sections/menu.dart').read_text()

def test_upgrade_674():
    assert 'v.trim().toLowerCase()' in (ROOT / 'lib/sections/menu.dart').read_text()

def test_upgrade_675():
    assert 'max 200 characters' in (ROOT / 'lib/sections/menu.dart').read_text()

def test_upgrade_676():
    assert "item['product_id'] is! int" in (ROOT / 'lib/sections/products_inventory.dart').read_text()

def test_upgrade_677():
    assert "historyEmployeeId == null || item['product_id'] is! int" in (ROOT / 'lib/sections/products_inventory.dart').read_text()

def test_upgrade_678():
    assert "'${result['reason']}'.trim().length < 3" in (ROOT / 'lib/sections/products_inventory.dart').read_text()

def test_upgrade_679():
    assert "result['incoming'] is! bool" in (ROOT / 'lib/sections/products_inventory.dart').read_text()

def test_upgrade_680():
    assert 'Invalid inventory quantity' in (ROOT / 'lib/sections/products_inventory.dart').read_text()

def test_upgrade_681():
    assert 'Invalid minimum stock quantity' in (ROOT / 'lib/sections/products_inventory.dart').read_text()

def test_upgrade_682():
    assert 'parsedDelta == parsedDelta.roundToDouble()' in (ROOT / 'lib/sections/products_inventory.dart').read_text()

def test_upgrade_683():
    assert 'Unknown movement' in (ROOT / 'lib/sections/products_inventory.dart').read_text()

def test_upgrade_684():
    assert '_refresh();' in (ROOT / 'lib/sections/products_inventory.dart').read_text()

def test_upgrade_685():
    assert 'Inventory update failed:' in (ROOT / 'lib/sections/products_inventory.dart').read_text()

