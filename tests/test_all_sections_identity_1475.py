import unittest,zipfile,os
ROOT=os.path.dirname(os.path.dirname(__file__))
class Upgrade1475Tests(unittest.TestCase):
 def test_all_sections_shared_lifecycle(self):
  s=open(os.path.join(ROOT,'lib/shared/section_shell.dart')).read()
  for x in ['WidgetsBindingObserver','addObserver(this)','removeObserver(this)','AppLifecycleState.resumed','_refreshAccess();','widget.sectionId == expectedSectionId']:
   self.assertIn(x,s)
 def test_second_person_approval(self):
  s=open(os.path.join(ROOT,'supabase/migrations/20261012_1475_independent_identity_approval.sql')).read()
  for x in ['v_mapping.verified_by=auth.uid()','mapping_id uuid not null unique','for update','enable row level security','gs_identity_approval_immutable']:
   self.assertIn(x,s)
 def test_never_certify_payment(self):
  s=open(os.path.join(ROOT,'supabase/migrations/20261012_1475_independent_identity_approval.sql')).read()
  for x in ["'invoice_settled',false","'unified_ledger_posted',false","'dashboard_certified',false"]:
   self.assertIn(x,s)
if __name__=='__main__':unittest.main()
