import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
CHANGES = json.loads((ROOT / 'UPGRADES_753_TO_772_MEASURED.json').read_text())

def test_twenty_sequential_unique_changes():
    assert [x['upgrade'] for x in CHANGES] == list(range(753,773))
    assert len({x['line'] for x in CHANGES}) == 20

def test_each_actual_code_change_removes_raw_exception():
    lines = (ROOT/'lib/sections/tables.dart').read_text().splitlines()
    for x in CHANGES:
        assert lines[x['line']-1].strip() == x['after']
        assert '$e' in x['before'] and '$e' not in x['after']
        assert 'Please retry or contact a manager' in x['after']

def test_each_checkpoint_has_documentation():
    for x in CHANGES:
        assert (ROOT/f"UPGRADE_{x['upgrade']}.md").is_file()

def test_all_seven_section_screens_remain_present():
    for name in ('dashboard','tables','table_orders','motel_orders','kitchen','menu','products_inventory'):
        assert (ROOT/'lib/sections'/f'{name}.dart').is_file()
