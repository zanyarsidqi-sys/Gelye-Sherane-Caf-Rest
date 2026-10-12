import importlib.util
from pathlib import Path
from tempfile import TemporaryDirectory

ROOT=Path(__file__).resolve().parents[2]
SPEC=importlib.util.spec_from_file_location('release1150', ROOT/'tools/verify_kitchen_release_1150.py')
module=importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)

def test_actual_project_release_artifacts_present():
    assert module.verify(ROOT) == []

def test_empty_project_fails_closed():
    with TemporaryDirectory() as d:
        assert module.verify(Path(d))

def test_missing_migration_fails_closed():
    with TemporaryDirectory() as d:
        base=Path(d)
        (base/'supabase/migrations').mkdir(parents=True)
        (base/'supabase/verification').mkdir(parents=True)
        assert any('1144' in s for s in module.verify(base))
