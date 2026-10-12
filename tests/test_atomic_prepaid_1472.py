import pathlib, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
SQL=(ROOT/'supabase/migrations/20261012_1472_atomic_prepaid_allocation_journal.sql').read_text()
DART=(ROOT/'lib/shared/payments_management_panel.dart').read_text()
class AtomicPrepaidContract(unittest.TestCase):
 def test_atomic_wrapper(self):
  self.assertIn('gs_financial_allocate_and_journal_verified_prepaid',SQL)
  self.assertIn('gs_financial_allocate_verified_motel_prepaid(p_receipt_id)',SQL)
  self.assertIn('gs_financial_post_motel_prepaid_settlement(v_allocation_id)',SQL)
 def test_fail_closed(self):
  self.assertIn("raise exception 'Prepaid journal reconciliation failed'",SQL)
  self.assertIn("raise exception 'Prepaid allocation response invalid'",SQL)
 def test_no_false_settlement(self):
  self.assertIn("'invoice_settled',false",SQL)
  self.assertIn("'unified_ledger_posted',false",SQL)
  self.assertIn("'dashboard_certified',false",SQL)
 def test_ui_uses_atomic_rpc(self):
  self.assertIn("client.rpc('gs_financial_allocate_and_journal_verified_prepaid'",DART)
  self.assertIn("result['journal_id'] is! String",DART)
 def test_ui_still_gated(self):
  self.assertIn("'GS_ENABLE_VERIFIED_PREPAID_ALLOCATION', defaultValue: false",DART)
if __name__=='__main__': unittest.main()
