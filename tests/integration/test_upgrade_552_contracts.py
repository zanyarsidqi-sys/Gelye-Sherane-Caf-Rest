from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = ROOT / 'supabase' / 'migrations'
class KitchenRevisionContractTests(unittest.TestCase):
    def test_migrations_present_and_ordered(self):
        for n in (539,540,541,544,545,546,549,550,551,552):
            self.assertEqual(len(list(MIGRATIONS.glob(f'20261010_{n}_*.sql'))),1)
    def test_closure_requires_confirmed_receipt(self):
        s = next(MIGRATIONS.glob('20261010_552_*.sql')).read_text()
        self.assertIn("if v_state is distinct from 'acknowledged_consistent' then",s)
        self.assertNotIn("v_state is distinct from 'failed_requires_recovery'",s)
        self.assertIn("gs_can_access('kitchen','can_edit')",s)
        self.assertIn('for update of c',s)
        self.assertIn('revoke all on function',s)
    def test_reconciliation_is_permission_scoped(self):
        s = next(MIGRATIONS.glob('20261010_546_*.sql')).read_text()
        self.assertIn("gs_can_access('kitchen','can_view')",s)
        self.assertIn('missing_receipt_audit',s)
        self.assertIn('timestamp_mismatch',s)
if __name__ == '__main__': unittest.main()
