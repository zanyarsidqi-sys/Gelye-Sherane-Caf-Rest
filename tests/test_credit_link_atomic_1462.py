import pathlib, re, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
SQL=(ROOT/'supabase/migrations/20261012_1462_credit_link_atomic_return.sql').read_text()
class CreditLinkContract(unittest.TestCase):
 def test_single_rpc(self): self.assertEqual(SQL.count('create or replace function public.gs_financial_post_verified_credit_charge'),1)
 def test_retry_requires_link(self): self.assertIn('Existing credit charge has no matching durable invoice linkage',SQL)
 def test_insert_requires_link(self): self.assertIn('Credit journal inserted without durable invoice linkage',SQL)
 def test_both_paths_linked(self): self.assertEqual(SQL.count('from public.gs_financial_credit_invoice_charge_links cl'),2)
 def test_source_invoice_in_both_responses(self): self.assertEqual(SQL.count("'finance_invoice_id',f.id"),2)
 def test_no_paid_invoice_write(self): self.assertNotRegex(SQL,r'update\s+public\.gs_motel_food_finance_invoices')
 def test_no_ledger_insert(self): self.assertNotRegex(SQL,r'insert\s+into\s+public\.gs_unified_payment_ledger')
 def test_authorization(self): self.assertIn("gs_can_access('credit_management','can_edit')",SQL)
 def test_locking(self): self.assertIn('for update',SQL.lower())
 def test_idempotency(self): self.assertIn('pg_advisory_xact_lock',SQL)
 def test_fail_closed(self): self.assertIn("'dashboard_certified',false",SQL)
 def test_no_prepaid_claim(self): self.assertIn("'prepaid_allocated',false",SQL)
if __name__=='__main__': unittest.main()
