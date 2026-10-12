import unittest, zipfile, pathlib, re
ROOT=pathlib.Path(__file__).resolve().parents[1]
class UpgradeTests(unittest.TestCase):
 def test_universal_section_registration(self):
  s=(ROOT/'lib/shared/section_shell.dart').read_text()
  block=s.split('_moduleFeatures',1)[1]
  self.assertGreaterEqual(block.count("': <String>["),35)
 def test_reset_clears_local_state(self):
  s=(ROOT/'lib/shared/section_shell.dart').read_text()
  m=re.search(r'void _resetSectionWorkspace\(\) \{(.*?)\n  \}',s,re.S)
  self.assertIsNotNone(m)
  for item in ['_workflowSearchController.clear()', '_sessionHandoverChecks.clear()', "_search = '';",'_refreshAccess()']:
   self.assertIn(item,m.group(1))
 def test_reset_action_wired(self):
  s=(ROOT/'lib/shared/section_shell.dart').read_text()
  self.assertIn('onPressed: _resetSectionWorkspace',s)
 def test_staging_read_only(self):
  s=(ROOT/'supabase/diagnostics/staging_assertions_1491.sql').read_text().upper()
  self.assertIn('BEGIN READ ONLY;',s)
  self.assertIn('ROLLBACK;',s)
  self.assertNotIn('INSERT INTO ',s)
  self.assertNotIn('UPDATE PUBLIC.',s)
 def test_runner_requires_explicit_staging(self):
  s=(ROOT/'tools/run_staging_assertions_1491.py').read_text()
  self.assertIn('GS_ENVIRONMENT',s)
  self.assertIn('STAGING_DATABASE_URL',s)
  self.assertIn("'--staging'",s)
if __name__=='__main__': unittest.main()
