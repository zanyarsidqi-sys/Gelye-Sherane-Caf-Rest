from pathlib import Path
s = (Path(__file__).resolve().parents[2] / 'lib/shared/inventory_catalog_panel.dart').read_text()

def test_pagination():
    assert 'pageSize = 500' in s and '.range(offset, offset + pageSize - 1)' in s

def test_session_check():
    assert 'currentUser?.id != employeeId' in s

def test_cap_warning():
    assert 'Limit reached: some products may be missing' in s
