import json, pathlib, re, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class UpgradeChecks(unittest.TestCase):
 def test_registry(self):
  d=json.loads((ROOT/'docs/verification_coverage_1481.json').read_text())
  self.assertEqual(len(d['section_ids']),35)
  self.assertEqual(len(set(d['section_ids'])),35)
 def test_shared_ui(self):
  s=(ROOT/'lib/shared/section_shell.dart').read_text()
  self.assertIn('_verificationChecklist()',s)
  self.assertIn('Runtime and financial certification not established',s)
  self.assertIn('Financial IQD reconciliation: not certified',s)
 def test_permission_refresh_fail_closed(self):
  s=(ROOT/'lib/shared/section_shell.dart').read_text()
  refresh=s.split('void _refreshAccess()')[1].split('void didUpdateWidget')[0]
  self.assertIn('_privacyShield = true;',refresh)
 def test_staging_diagnostic_read_only(self):
  s=(ROOT/'supabase/diagnostics/financial_staging_readonly_1481.sql').read_text()
  self.assertIn('BEGIN READ ONLY;',s)
  self.assertIn('ROLLBACK;',s)
  self.assertNotIn('UPDATE ',s)
  self.assertNotIn('INSERT INTO ',s)
if __name__=='__main__': unittest.main()
