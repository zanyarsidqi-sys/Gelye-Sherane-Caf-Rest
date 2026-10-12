from pathlib import Path
import unittest
root=Path(__file__).resolve().parents[1]
sql=(root/'supabase/migrations/20261012_1471_motel_prepaid_settlement_journal.sql').read_text()
smoke=(root/'supabase/diagnostics/motel_prepaid_settlement_smoke_1471.sql').read_text()
class JournalContracts(unittest.TestCase):
 def test_invoice_uuid_without_guess(self):
  self.assertIn('finance_invoice_id uuid not null unique',sql)
  self.assertNotIn('::bigint',sql)
 def test_atomic_post_and_replay(self):
  self.assertIn('for update',sql)
  self.assertIn("'already_posted',true",sql)
  self.assertIn("'already_posted',false",sql)
 def test_no_false_certification(self):
  self.assertEqual(sql.count("'dashboard_certified',false"),2)
  self.assertEqual(sql.count("'unified_ledger_posted',false"),2)
 def test_security(self):
  self.assertIn('enable row level security',sql)
  self.assertIn('append-only',sql)
  self.assertIn("gs_can_access('invoices_payments','can_edit')",sql)
 def test_smoke_rollback(self):
  self.assertIn('BEGIN;',smoke)
  self.assertIn('ROLLBACK;',smoke)
if __name__=='__main__': unittest.main()
