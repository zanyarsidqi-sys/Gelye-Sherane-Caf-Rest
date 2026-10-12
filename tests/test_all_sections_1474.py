import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]

class UniversalSectionContextTest(unittest.TestCase):
    def test_all_35_registered_sections(self):
        registry = (ROOT / 'lib/app/section_registry.dart').read_text()
        ids = re.findall(r"CafeSection\(\s*'([^']+)'", registry)
        self.assertEqual(len(ids), 35)
        self.assertEqual(len(set(ids)), 35)

    def test_context_after_permission_gate(self):
        shell = (ROOT / 'lib/shared/section_shell.dart').read_text()
        gate = shell.index('if (snapshot.data != true || snapshot.hasError)')
        context = shell.index('Upgrade universal section safety context')
        self.assertLess(gate, context)
        self.assertIn('Financial totals require independent reconciliation', shell)
        self.assertIn('widget.authorizedContent', shell)

    def test_footer_and_navigation_retained(self):
        shell = (ROOT / 'lib/shared/section_shell.dart').read_text()
        self.assertIn('All Rights Reserved to Gelye Sherane', shell)
        self.assertIn('Navigator.of(context).maybePop()', shell)

if __name__ == '__main__': unittest.main()
