import pathlib,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class Upgrade1490Tests(unittest.TestCase):
 def test_35_sections(self):
  s=(ROOT/'lib/shared/section_shell.dart').read_text();part=s.split('static const Map<String, List<String>> _moduleFeatures = {',1)[1].split('  };',1)[0]
  import re
  self.assertEqual(len(set(re.findall(r"^    '([a-z_]+)': <String>\[",part,re.M))),35)
 def test_action_checks_generation(self):
  s=(ROOT/'lib/shared/section_shell.dart').read_text();block=s.split('Future<void> _copyCompletedHandover',1)[1].split('IconData _sectionIcon',1)[0]
  for token in ['await permissionCheck','identical(permissionCheck, _accessFuture)','generation != _accessGeneration','employee == null','_privacyShield']:
   self.assertIn(token,block)
 def test_sql_independent_approvers(self):
  s=(ROOT/'supabase/migrations/20261012_1490_independent_mapping_consistency.sql').read_text()
  self.assertIn('v_approval.approved_by <> v_mapping.verified_by',s)
  self.assertIn('v_review.reviewed_by<>v_review.submitted_by',s)
 def test_sql_blocks_settlement(self):
  s=(ROOT/'supabase/migrations/20261012_1490_independent_mapping_consistency.sql').read_text().lower()
  for token in ["'settlement_authorized',false","'invoice_paid',false","'unified_ledger_posted',false","'identity_authoritatively_verified',false"]:self.assertIn(token,s)
  for forbidden in ['update public.', 'insert into public.', 'delete from public.'] :self.assertNotIn(forbidden,s)
 def test_permissions_and_conflicts(self):
  s=(ROOT/'supabase/migrations/20261012_1490_independent_mapping_consistency.sql').read_text()
  for token in ['auth.uid() is null','gs_can_access','v_mapping_conflicts','v_review_conflicts',"review_state <> 'rejected'"] :self.assertIn(token,s)
if __name__=='__main__':unittest.main()
