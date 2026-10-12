import unittest, zipfile, pathlib, sys
class FinanceEvidenceContract(unittest.TestCase):
 def test_sql(self):
  root=pathlib.Path(__file__).resolve().parents[1]
  sql=(root/'supabase/migrations/20261012_1466_invoice_evidence_status.sql').read_text()
  for phrase in ['security definer','auth.uid()','gs_can_access','source_integrity_matched','payment_method_conflict',"'dashboard_certified',false", "'invoice_settled',false", "'unified_ledger_posted',false",'grant execute']:
   with self.subTest(phrase=phrase): self.assertIn(phrase,sql)
 def test_staging_read_only(self):
  root=pathlib.Path(__file__).resolve().parents[1]
  sql=(root/'supabase/diagnostics/financial_evidence_staging_1466.sql').read_text()
  self.assertIn('BEGIN READ ONLY',sql)
  self.assertIn('ROLLBACK;',sql)
  self.assertIn('receipt allocation mismatch',sql)
if __name__=='__main__':unittest.main()
