import json,pathlib,re,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class AuditTest(unittest.TestCase):
 def test_all_35(self):
  d=json.loads((ROOT/'docs/section_audit_1480.json').read_text())
  self.assertEqual(len(d['sections']),35)
  self.assertEqual(len(set(x['section_id'] for x in d['sections'])),35)
 def test_source_status_explicit(self):
  s=(ROOT/'lib/shared/section_shell.dart').read_text()
  self.assertIn('Planning preview only',s)
  self.assertIn('_hasImplementedPanel',s)
  self.assertIn('widget.authorizedContent != null',s)
 def test_financial_diagnostic_read_only(self):
  s=(ROOT/'supabase/diagnostics/staging_schema_1480.sql').read_text().upper()
  self.assertIn('BEGIN READ ONLY',s)
  self.assertIn('ROLLBACK',s)
  self.assertNotRegex(s,r'(?m)^\s*(INSERT|UPDATE|DELETE|ALTER|DROP|CREATE)\b')
 def test_no_false_certification(self):
  d=json.loads((ROOT/'docs/section_audit_1480.json').read_text())
  self.assertTrue(all(not x['financially_certified'] for x in d['sections']))
if __name__=='__main__': unittest.main()
