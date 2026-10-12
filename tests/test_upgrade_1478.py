import unittest,zipfile,os
ROOT=os.path.dirname(os.path.dirname(__file__))
class Upgrade1478Tests(unittest.TestCase):
 def test_shared_privacy_guard(self):
  s=open(os.path.join(ROOT,'lib/shared/section_shell.dart')).read()
  self.assertIn('if (_privacyShield) return _privacyLocked();',s)
  self.assertIn('Verify access to reveal',s)
  self.assertIn('identical(_accessFuture, check)',s)
 def test_gate_does_not_settle(self):
  s=open(os.path.join(ROOT,'supabase/migrations/20261012_1478_approved_identity_settlement_gate.sql')).read()
  self.assertIn('gs_financial_review_approved_identity_integrity',s)
  self.assertIn("'unified_ledger_posted',false",s)
  self.assertNotIn('update public.gs_motel_food_finance_invoices',s.lower())
 def test_section_registry(self):
  s=open(os.path.join(ROOT,'lib/shared/section_shell.dart')).read()
  registry=s.split('static const Map<String, List<String>> _moduleFeatures = {',1)[1].split('};',1)[0]
  self.assertEqual(len(__import__('re').findall(r"^    '[a-z_]+': <String>\[",registry,__import__('re').M)),35)
if __name__=='__main__': unittest.main()
