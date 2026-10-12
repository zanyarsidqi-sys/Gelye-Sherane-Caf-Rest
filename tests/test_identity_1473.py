import unittest, pathlib
ROOT=pathlib.Path(__file__).resolve().parents[1]
M=(ROOT/'supabase/migrations/20261012_1473_motel_cafe_identity_evidence.sql').read_text()
D=(ROOT/'supabase/diagnostics/identity_staging_1473.sql').read_text()
class IdentitySourceTests(unittest.TestCase):
 def test_distinct_source_ids(self):
  self.assertIn('finance_invoice_id uuid not null unique',M)
  self.assertIn('cafe_order_id bigint not null unique',M)
 def test_no_fake_settlement(self):
  self.assertIn("'invoice_settled',false",M)
  self.assertIn("'unified_ledger_posted',false",M)
  self.assertIn("'dashboard_certified',false",M)
 def test_permissions_and_append_only(self):
  self.assertIn("gs_can_access('invoices_payments','can_edit')",M)
  self.assertIn('before update or delete',M)
  self.assertIn('enable row level security',M)
 def test_conflict_and_evidence(self):
  self.assertIn('Conflicting source identity',M)
  self.assertIn('evidence_description',M)
 def test_staging_preflight(self):
  self.assertIn('BEGIN READ ONLY;',D)
  self.assertIn('ROLLBACK;',D)
if __name__=='__main__': unittest.main()
