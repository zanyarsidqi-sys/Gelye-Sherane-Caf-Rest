import unittest, pathlib, re, json
ROOT=pathlib.Path(__file__).resolve().parents[1]
class TestUpgrade1482(unittest.TestCase):
 def test_all_sections(self):
  s=(ROOT/'lib/shared/section_shell.dart').read_text()
  ids=re.findall(r"^    '([a-z_]+)': <String>\[",s,re.M)
  self.assertEqual(len(ids),35)
  self.assertEqual(len(set(ids)),35)
 def test_generation_guard(self):
  s=(ROOT/'lib/shared/section_shell.dart').read_text()
  self.assertIn('generation == _accessGeneration',s)
  self.assertIn('userAtStart == user.id',s)
  self.assertIn('widget.sectionId == sectionAtStart',s)
 def test_hide_invalidates_pending_check(self):
  s=(ROOT/'lib/shared/section_shell.dart').read_text()
  segment=s.split('void _lockSection()')[1].split('void _unlockAndRecheck()')[0]
  self.assertIn('_accessGeneration++',segment)
  self.assertIn('_privacyShield = true',segment)
 def test_audit_no_false_certification(self):
  d=json.loads((ROOT/'docs/SECTION_SECURITY_AUDIT_1482.json').read_text())
  self.assertEqual(d['section_count'],35)
  self.assertFalse(d['settlement_certified'])
  self.assertFalse(d['staging_executed'])
 def test_sql_read_only(self):
  s=(ROOT/'supabase/diagnostics/staging_prerequisites_1482.sql').read_text()
  self.assertIn('BEGIN READ ONLY;',s)
  self.assertIn('ROLLBACK;',s)
if __name__=='__main__': unittest.main()
