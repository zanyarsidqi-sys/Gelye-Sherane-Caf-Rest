import pathlib, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
S=(ROOT/'lib/shared/section_shell.dart').read_text()
class UpgradeTests(unittest.TestCase):
 def test_section_scoped(self):
  self.assertIn('_sessionHandoverChecks.putIfAbsent(sectionId',S)
  self.assertIn("ValueKey('handover_$sectionId')",S)
 def test_real_interaction(self):
  self.assertIn('CheckboxListTile(',S)
  self.assertIn('checked.add(index)',S)
  self.assertIn('checked.remove(index)',S)
  self.assertIn('setState(checked.clear)',S)
 def test_security(self):
  self.assertIn('_sessionHandoverChecks.clear();',S)
  self.assertLess(S.index('if (_privacyShield) return _privacyLocked()'),S.index('_sectionHandoverChecklist(),'))
 def test_no_false_financial_claim(self):
  self.assertIn('No task is submitted, paid, approved or synchronized.',S)
  self.assertIn('Financial IQD reconciliation: not certified',S)
 def test_coverage(self):
  self.assertEqual(S.count('  Widget _sectionHandoverChecklist()'),1)
  self.assertIn('Expanded(child: widget.authorizedContent ??',S)
if __name__=='__main__': unittest.main()
