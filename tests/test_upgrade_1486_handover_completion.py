import unittest,zipfile,os
class UpgradeTests(unittest.TestCase):
 def setUp(self):
  self.z=zipfile.ZipFile(os.environ['UPGRADE_ZIP'])
  self.s=self.z.read('gelye_cafe_rest/lib/shared/section_shell.dart').decode()
 def test_section_registry(self):
  registry=self.s.split('static const Map<String, List<String>> _moduleFeatures = {',1)[1].split('  };',1)[0]
  import re
  self.assertEqual(len(re.findall(r"^    '[a-z_]+': <String>\[",registry,re.M)),35)
 def test_completion_gated(self):
  self.assertIn('checked.length == _handoverSteps.length',self.s)
  self.assertIn('checks.length != _handoverSteps.length',self.s)
 def test_sensitive_financial_state_not_certified(self):
  self.assertIn('Financial totals are not certified.',self.s)
  self.assertIn('no remote task, approval, payment, or reconciliation performed.',self.s)
 def test_privacy_and_access_preserved(self):
  self.assertIn('if (!mounted || widget.sectionId != sectionId || _privacyShield) return;',self.s)
  self.assertIn('_checkAccess()',self.s)
  self.assertIn('Section hidden for privacy',self.s)
 def test_existing_footer(self):
  self.assertIn('Powered By Zanyar Sidqi',self.s)
if __name__=='__main__': unittest.main()
