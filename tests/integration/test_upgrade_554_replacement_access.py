"""Static contract tests; not a substitute for live Supabase role tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MIG = ROOT / 'supabase' / 'migrations'

class ReplacementAccessTests(unittest.TestCase):
    def test_legacy_overload_is_explicitly_revoked(self):
        sql = (MIG / '20261010_554_disable_legacy_replacement_bypass.sql').read_text().lower()
        self.assertIn('revoke all on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text)', sql)
        self.assertIn('from public, anon, authenticated', sql)

    def test_confirmed_overload_retains_authenticated_execute(self):
        sql = (MIG / '20261010_554_disable_legacy_replacement_bypass.sql').read_text().lower()
        self.assertIn('grant execute on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text,bigint)', sql)
        self.assertIn('to authenticated', sql)

    def test_confirmed_overload_validates_server_price(self):
        sql = (MIG / '20261010_538_replacement_price_confirmation.sql').read_text().lower() if (MIG / '20261010_538_replacement_price_confirmation.sql').exists() else '\n'.join(p.read_text().lower() for p in MIG.glob('*538*.sql'))
        self.assertIn('p_confirmed_new_unit_price_iqd <> v_new_price', sql)
        self.assertIn("gs_can_access('table_orders','can_edit')", sql)

if __name__ == '__main__':
    unittest.main()
