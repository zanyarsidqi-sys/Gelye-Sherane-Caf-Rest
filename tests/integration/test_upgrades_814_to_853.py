from pathlib import Path
import json
import pytest
ROOT = Path(__file__).resolve().parents[2]
CHECKS = json.loads((ROOT / 'SECTION_01_TO_07_AUDIT_853.json').read_text())['checks']

@pytest.mark.parametrize('check', CHECKS, ids=lambda c: str(c['upgrade']))
def test_source_contract(check):
    assert check['needle'] in (ROOT / check['path']).read_text()

def test_checkpoint_sequence():
    assert [c['upgrade'] for c in CHECKS] == list(range(814, 854))

def test_history_does_not_silently_discard_malformed_entries():
    text = (ROOT / 'lib/sections/products_inventory.dart').read_text()
    assert '.whereType<Map>()' not in text
    assert 'row is! Map' in text and 'row.keys.any((key) => key is! String)' in text
