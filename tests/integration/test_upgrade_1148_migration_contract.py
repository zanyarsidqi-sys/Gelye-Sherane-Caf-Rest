import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from verify_kitchen_migration_contract_1148 import run_checks


def test_kitchen_migration_contracts():
    checks = run_checks()
    assert len(checks) == 12
    assert all(c['passed'] for c in checks), [c for c in checks if not c['passed']]


def test_detector_rejects_removed_permission_check(monkeypatch):
    # This test confirms the checker really rejects an authorization regression.
    import verify_kitchen_migration_contract_1148 as mod
    original = Path.read_text
    def altered(self, *args, **kwargs):
        content = original(self, *args, **kwargs)
        if self.name.endswith('_1143_kitchen_served_item_row_locks.sql'):
            return content.replace("gs_can_access('kitchen', 'can_edit')", 'false')
        return content
    monkeypatch.setattr(Path, 'read_text', altered)
    assert not next(c for c in mod.run_checks() if c['name'] == 'status RPC enforces employee permission')['passed']
