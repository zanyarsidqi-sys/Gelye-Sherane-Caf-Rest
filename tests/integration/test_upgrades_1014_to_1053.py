from pathlib import Path
import json
import pytest
ROOT=Path(__file__).resolve().parents[2]
AUDIT=json.loads((ROOT/'ALL_35_SECTIONS_PROGRESS_1053.json').read_text())
@pytest.mark.parametrize('check',AUDIT['checks'],ids=lambda c:str(c['upgrade']))
def test_checkpoint(check):
    assert check['needle'] in (ROOT/check['path']).read_text()
def test_all_35_section_files_and_wrappers():
    assert len(AUDIT['sections'])==35
    assert all(r['source_file_present'] for r in AUDIT['sections'])
    assert sum(r['permission_shell_present'] for r in AUDIT['sections'])==30
def test_upgrade_sequence():
    assert [c['upgrade'] for c in AUDIT['checks']]==list(range(1014,1054))
def test_price_string_and_limit_guards():
    s=(ROOT/'lib/shared/inventory_catalog_panel.dart').read_text()
    assert 'num.tryParse(value.trim())' in s
    assert 'loaded.length > maximumRows' in s
    assert "(row['normal_price_iqd'] as num?)" not in s
