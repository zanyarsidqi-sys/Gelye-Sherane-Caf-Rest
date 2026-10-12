import pathlib, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
S=(ROOT/'lib/shared/section_shell.dart').read_text()
SQL=next((ROOT/'supabase/migrations').glob('*_financial_crosswalk_settlement_readiness.sql')).read_text()
class Tests(unittest.TestCase):
 def test_all_sections(self):
  assert S.count("'dashboard': <String>[")==1
  assert S.count("'nargile_management': <String>[")==1
  assert 'Widget _verificationChecklist()' in S
 def test_clipboard_fail_closed(self):
  a=S.split('Future<void> _copySectionSupportSummary() async {',1)[1].split('Widget _verificationChecklist()',1)[0]
  for x in ['_privacyShield','_accessFuture','generationAtStart','_permissionUserId','userAtStart','widget.sectionId != sectionAtStart']: assert x in a
 def test_financial_no_writes(self):
  low=SQL.lower()
  for x in ['insert into','update public.','delete from','truncate ','alter table','drop table']: assert x not in low
  assert "'ready_to_settle',false" in low
  assert "'standing_cash_certified_iqd',null" in low
 def test_independent_review_and_conflicts(self):
  for x in ['reviewed_by<>v_e.submitted_by','conflicting_reviewed_links',"review_state='reviewed_unverified'"]: assert x in SQL
 def test_permission_and_no_public_execute(self):
  for x in ['auth.uid() is null','gs_can_access','revoke all on function','to authenticated']: assert x in SQL
if __name__=='__main__': unittest.main()
