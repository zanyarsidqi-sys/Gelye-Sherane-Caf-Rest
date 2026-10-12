import pathlib,zipfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
S=(ROOT/'lib/shared/section_shell.dart').read_text()
class SharedReviewSecurityTests(unittest.TestCase):
 def test_clears_on_background(self):
  self.assertIn('_sessionHandoverChecks.clear();\n          _privacyShield = true;',S)
 def test_clears_on_manual_lock(self):
  self.assertIn('_accessGeneration++;\n      _sessionHandoverChecks.clear();',S)
 def test_clears_on_section_change(self):
  self.assertIn("_search = '';\n      _sessionHandoverChecks.clear();",S)
 def test_mutation_guard(self):
  self.assertIn('widget.sectionId != sectionId || _privacyShield ||',S)
  self.assertIn('currentUser?.id != _permissionUserId',S)
 def test_all_35(self):
  import re
  ids=re.findall(r"^\s*'([a-z_]+)':\s*<String>\[",S,re.M)
  self.assertEqual(len(set(ids)),35)
 def test_staging_read_only(self):
  sql=(ROOT/'supabase/diagnostics/settlement_gate_1487.sql').read_text().upper()
  for keyword in ['INSERT INTO','UPDATE ','DELETE FROM','DROP TABLE','ALTER TABLE']:
   self.assertNotIn(keyword,sql)
if __name__=='__main__': unittest.main()
