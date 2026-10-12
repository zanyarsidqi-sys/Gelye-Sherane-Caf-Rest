import importlib.util
from pathlib import Path
import pytest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('gate', ROOT / 'tools/run_kitchen_staging_gate_1151.py')
gate = importlib.util.module_from_spec(spec)
spec.loader.exec_module(gate)


def test_rejects_empty_or_malformed_output():
    for value in ('', 'only one column\n', 'check,unknown\n', ',t\n'):
        with pytest.raises(ValueError):
            gate.parse_check_rows(value)


def test_parses_valid_true_and_false():
    assert gate.parse_check_rows('one,t\ntwo,false,reason\n') == [('one', True), ('two', False)]


def test_requires_staging_confirmation():
    assert gate.main([]) == 2


def test_all_four_sql_artifacts_present():
    assert len(gate.CHECKS) == 4
    assert all(p.is_file() for p in gate.CHECKS)
