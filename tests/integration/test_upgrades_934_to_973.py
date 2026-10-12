from pathlib import Path
import json
import pytest
ROOT=Path(__file__).resolve().parents[2]
CHECKS=json.loads((ROOT/'SECTION_01_TO_07_AUDIT_973.json').read_text())['checks']
@pytest.mark.parametrize('check',CHECKS,ids=lambda c:str(c['upgrade']))
def test_source_contract(check):
    assert check['needle'] in (ROOT/check['path']).read_text()
def test_contiguous_checkpoints():
    assert [c['upgrade'] for c in CHECKS]==list(range(934,974))
def test_ledger_rejects_invalid_delta_before_list_render():
    s=(ROOT/'lib/sections/products_inventory.dart').read_text()
    assert s.index("if (rows.any((row) => _movementInteger(row['delta']) == null))") < s.index('return ListView.builder(')
def test_malformed_rows_rejected_before_movement_validation():
    s=(ROOT/'lib/sections/products_inventory.dart').read_text()
    assert s.index('row.keys.any((key) => key is! String)))') < s.index("if (rows.any((row) => _movementInteger(row['delta']) == null))")
