import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHANGES = json.loads((ROOT / 'UPGRADES_733_TO_752_MEASURED.json').read_text())

def test_all_twenty_checkpoints_are_unique_and_documented():
    assert [c['upgrade'] for c in CHANGES] == list(range(733, 753))
    assert len({(c['file'], c['original_line']) for c in CHANGES}) == 20

def test_selected_employee_messages_no_longer_expose_raw_errors():
    for change in CHANGES:
        line = (ROOT / change['file']).read_text().splitlines()[change['original_line'] - 1]
        assert line.strip() == change['after']
        assert 'Please retry or contact a manager' in line
        assert '$e' not in line

def test_previous_raw_error_was_actually_removed():
    for change in CHANGES:
        assert '$e' in change['before']
        assert change['before'] != change['after']

def test_all_priority_section_files_remain_present():
    for name in ('dashboard','tables','table_orders','motel_orders','kitchen','menu','products_inventory'):
        assert (ROOT / 'lib' / 'sections' / f'{name}.dart').is_file()
