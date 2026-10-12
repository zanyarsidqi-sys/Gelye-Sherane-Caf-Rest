"""Offline regression contracts; these do NOT replace live Supabase tests."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
M = ROOT / 'supabase' / 'migrations'
UI = (ROOT / 'lib' / 'sections' / 'table_orders.dart').read_text()

def migration(number):
    paths = list(M.glob(f'20261010_{number}_*.sql'))
    if len(paths) != 1:
        raise AssertionError(f'Expected exactly one migration for {number}, got {len(paths)}')
    return paths[0].read_text().lower()

class ReplacementIntegrationContracts(unittest.TestCase):
    def test_price_quote_and_commit_are_server_authoritative(self):
        s = migration(538)
        self.assertIn('gs_quote_unaccepted_table_replacement', s)
        self.assertIn('gs_replace_unaccepted_table_item', s)
        self.assertIn('p_confirmed_new_unit_price_iqd <> v_new_price', s)
        self.assertIn('case when v_mode then tourism_price_iqd else normal_price_iqd end', s)
        self.assertIn("gs_can_access('table_orders','can_edit')", s)
        self.assertIn('for update', s)
        self.assertIn('for share', s)

    def test_financial_and_kitchen_barriers_in_commit(self):
        s = migration(538)
        for relation in ('gs_cafe_order_station_ticket_items',
                         'gs_admin_discount_invoice_snapshots',
                         'gs_item_payment_allocations', 'gs_cash_payments',
                         'gs_unified_payment_ledger', 'gs_external_payment_evidence'):
            self.assertIn(relation, s)
        self.assertIn("v_fulfillment <> 'not_accepted'", s)
        self.assertIn("'kitchen_revision'", s)
        self.assertIn("'employee_notification'", s)
        self.assertIn("'customer_update'", s)
        self.assertIn('before_snapshot', s)
        self.assertIn('after_snapshot', s)

    def test_reconciliation_and_case_closure_are_guarded(self):
        reconciliation = migration(546)
        closure = migration(552)
        self.assertIn("gs_can_access('kitchen','can_view')", reconciliation)
        self.assertIn("'acknowledged_consistent'", closure)
        self.assertIn("gs_can_access('kitchen','can_edit')", closure)
        self.assertIn('for update of c', closure)
        self.assertIn('revoke all on function', closure)

    def test_flutter_uses_server_rpc_for_replacement_and_receipt(self):
        for rpc in ('gs_quote_unaccepted_table_replacement',
                    'gs_replace_unaccepted_table_item',
                    'gs_staff_kitchen_revision_reconciliation',
                    'gs_acknowledge_table_replacement_kitchen_revision',
                    'gs_staff_close_kitchen_revision_exception'):
            self.assertIn(rpc, UI)

    def test_migration_sequence_is_unique(self):
        numbers = (538,539,540,541,544,545,546,549,550,551,552)
        for number in numbers:
            migration(number)

if __name__ == '__main__':
    unittest.main()
