import pathlib, unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
SHELL = (ROOT/'lib/shared/section_shell.dart').read_text()
class SharedSupportTests(unittest.TestCase):
    def test_clipboard_real_api(self):
        self.assertIn('Clipboard.setData(ClipboardData(text: report))', SHELL)
    def test_no_sensitive_data_in_report(self):
        report = SHELL.split('final report = <String>[')[1].split('].join')[0]
        for forbidden in ('auth.currentUser', 'session.accessToken', 'invoice.amount', 'customer_name'):
            self.assertNotIn(forbidden, report)
    def test_guarded_after_permission(self):
        self.assertIn('if (_privacyShield) return _privacyLocked();', SHELL)
        self.assertIn('snapshot.data != true', SHELL)
    def test_all_section_shell(self):
        self.assertIn('Widget _verificationChecklist()', SHELL)
        self.assertIn('onPressed: _copySectionSupportSummary', SHELL)
if __name__=='__main__': unittest.main()
