from pathlib import Path
import json
import pytest

ROOT = Path(__file__).resolve().parents[2]
CHECKS = json.loads((ROOT / 'SECTION_01_TO_07_AUDIT_813.json').read_text())['checkpoints']

@pytest.mark.parametrize('check', CHECKS, ids=lambda x: str(x['upgrade']))
def test_source_acceptance(check):
    source = (ROOT / check['path']).read_text()
    assert check['needle'] in source

def test_checkpoints_numbered_contiguously():
    assert [x['upgrade'] for x in CHECKS] == list(range(774, 814))
