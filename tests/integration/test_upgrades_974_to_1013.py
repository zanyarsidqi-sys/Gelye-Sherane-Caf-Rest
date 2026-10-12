from pathlib import Path
import json
import pytest
ROOT=Path(__file__).resolve().parents[2]
CHECKS=json.loads((ROOT/'SECTION_01_TO_07_AUDIT_1013.json').read_text())['checks']
@pytest.mark.parametrize('check',CHECKS,ids=lambda c:str(c['upgrade']))
def test_source_contract(check):
    assert check['needle'] in (ROOT/check['path']).read_text()
def test_contiguous_upgrades():
    assert [c['upgrade'] for c in CHECKS]==list(range(974,1014))
def test_catalog_does_not_expose_raw_backend_errors():
    s=(ROOT/'lib/shared/inventory_catalog_panel.dart').read_text()
    assert "SelectableText('${snapshot.error}')" not in s
    assert "Text('${snapshot.error}')" not in s
def test_catalog_auth_listener_disposed():
    s=(ROOT/'lib/shared/inventory_catalog_panel.dart').read_text()
    assert s.index('onAuthStateChange.listen') < s.index('_authSubscription?.cancel()')
def test_catalog_session_guard_precedes_render():
    s=(ROOT/'lib/shared/inventory_catalog_panel.dart').read_text()
    assert s.index('currentUser?.id != _loadedEmployeeId') < s.index('final all = snapshot.data')
