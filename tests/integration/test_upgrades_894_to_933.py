from pathlib import Path
import json
import pytest
ROOT=Path(__file__).resolve().parents[2]
CHECKS=json.loads((ROOT/'SECTION_01_TO_07_AUDIT_933.json').read_text())['checks']
@pytest.mark.parametrize('check',CHECKS,ids=lambda c:str(c['upgrade']))
def test_source_contract(check):
    assert check['needle'] in (ROOT/check['path']).read_text()
def test_contiguous_upgrades():
    assert [c['upgrade'] for c in CHECKS]==list(range(894,934))
def test_overview_guard_precedes_conversion():
    s=(ROOT/'lib/sections/products_inventory.dart').read_text()
    assert s.index("if (row is! Map || row.keys.any((key) => key is! String))")<s.index('final item = Map<String, dynamic>.from(row)')
def test_invalid_movement_is_not_silently_rendered_as_zero():
    s=(ROOT/'lib/sections/products_inventory.dart').read_text()
    assert "if (delta == null) {" in s
    assert "(delta ?? 0)" not in s
