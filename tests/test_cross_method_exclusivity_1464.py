import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SQL=(ROOT/'supabase/migrations/20261012_1464_cross_method_exclusivity.sql').read_text()
AUDIT=(ROOT/'supabase/diagnostics/cross_method_collision_audit_1464.sql').read_text()

class FinancialContract(unittest.TestCase):
 def test_credit_rpc_rejects_prepaid(self):
  self.assertIn('Verified prepaid allocation already exists for invoice',SQL)
 def test_direct_journal_link_rejects_prepaid(self):
  self.assertIn('Prepaid allocation already exists for invoice',SQL)
 def test_prepaid_rejects_unlinked_historical_credit(self):
  self.assertIn('Existing historical credit journal charge blocks prepaid allocation',SQL)
 def test_exclusive_invoice_lock_in_all_three(self):
  self.assertGreaterEqual(SQL.lower().count('for update'),3)
 def test_staging_audit_detects_all_collisions(self):
  for x in ['CREDIT_PREPAID_COLLISION','CASH_PREPAID_COLLISION','HISTORICAL_CREDIT_PREPAID_COLLISION']: self.assertIn(x,AUDIT)
 def test_no_fake_dashboard_certification(self):
  self.assertNotIn("'dashboard_certified',true",SQL.lower())

if __name__=='__main__': unittest.main()
