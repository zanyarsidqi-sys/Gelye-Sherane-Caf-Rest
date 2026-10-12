import unittest,zipfile,os
ROOT=os.path.dirname(os.path.dirname(__file__))
class SharedSectionAndIdentityTests(unittest.TestCase):
 def test_filter_controller(self):
  s=open(os.path.join(ROOT,'lib/shared/section_shell.dart')).read()
  self.assertIn('controller: _workflowSearchController',s)
  self.assertIn('_workflowSearchController.clear();',s)
  self.assertIn('_workflowSearchController.dispose();',s)
 def test_identity_read_only(self):
  s=open(os.path.join(ROOT,'supabase/migrations/20261012_1477_identity_integrity_review.sql')).read().lower()
  self.assertIn('identity_valid',s)
  self.assertIn('approved_by=v_mapping.verified_by',s)
  self.assertIn('from public.gs_orders',s)
  self.assertNotIn('insert into',s)
  self.assertNotIn('update public.',s)
 def test_no_certification(self):
  s=open(os.path.join(ROOT,'supabase/migrations/20261012_1477_identity_integrity_review.sql')).read().lower()
  self.assertIn("'dashboard_certified',false",s)
  self.assertIn("'unified_ledger_posted',false",s)
if __name__=='__main__': unittest.main()
