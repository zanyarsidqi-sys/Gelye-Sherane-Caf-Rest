import pathlib,unittest,re
ROOT=pathlib.Path(__file__).resolve().parents[1]
class AccessTimeoutContracts(unittest.TestCase):
 def test_all_three_network_calls_bounded(self):
  s=(ROOT/'lib/shared/section_shell.dart').read_text()
  self.assertEqual(s.count('.timeout(_permissionTimeout)'),3)
  self.assertIn('Duration(seconds: 12)',s)
 def test_failure_closed(self):
  s=(ROOT/'lib/shared/section_shell.dart').read_text()
  self.assertRegex(s,r'catch \(_\) \{\s*return false;')
 def test_all_sections_present(self):
  s=(ROOT/'lib/shared/section_shell.dart').read_text()
  ids=re.findall(r"^    '([a-z][a-z_]+)': <String>\[",s,re.M)
  self.assertEqual(len(ids),35)
  self.assertEqual(len(set(ids)),35)
 def test_staging_script_read_only(self):
  sql=(ROOT/'supabase/diagnostics/staging_preflight_1483.sql').read_text()
  self.assertIn('BEGIN READ ONLY;',sql)
  self.assertIn('ROLLBACK;',sql)
  self.assertNotRegex(sql,r'(?im)^\s*(insert|update|delete|alter|drop|create)\s')
if __name__=='__main__':unittest.main()
