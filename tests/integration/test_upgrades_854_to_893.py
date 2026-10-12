from pathlib import Path
import json
import pytest
ROOT = Path(__file__).resolve().parents[2]
CHECKS = json.loads((ROOT/'SECTION_01_TO_07_AUDIT_893.json').read_text())['checks']

@pytest.mark.parametrize('check', CHECKS, ids=lambda c: str(c['upgrade']))
def test_contract(check):
    assert check['needle'] in (ROOT/check['path']).read_text()

def test_contiguous_checkpoint_numbers():
    assert [c['upgrade'] for c in CHECKS] == list(range(854, 894))

def test_history_map_key_validation_before_cast():
    source=(ROOT/'lib/sections/products_inventory.dart').read_text()
    guard=source.index('row.keys.any((key) => key is! String)')
    conversion=source.index('Map<String, dynamic>.from(r as Map)')
    assert guard < conversion
