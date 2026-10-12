import pathlib
import unittest

ROOT=pathlib.Path(__file__).resolve().parents[1]
SHELL=(ROOT/'lib/shared/section_shell.dart').read_text()
STAGING=(ROOT/'supabase/diagnostics/financial_staging_schema_1479.sql').read_text()

class SectionSafetyTests(unittest.TestCase):
    def test_background_locks_all_shared_sections(self):
        self.assertIn('AppLifecycleState.paused',SHELL)
        self.assertIn('AppLifecycleState.inactive',SHELL)
        self.assertIn('AppLifecycleState.hidden',SHELL)
        self.assertIn('setState(() => _privacyShield = true)',SHELL)
        self.assertIn('widget.authorizedContent ??',SHELL)
    def test_auth_change_locks_before_revalidation(self):
        callback=SHELL.split('onAuthStateChange.listen',1)[1].split('});',1)[0]
        self.assertLess(callback.index('_privacyShield = true'),callback.index('_refreshAccess()'))
    def test_section_change_locks_and_resets_search(self):
        callback=SHELL.split('void didUpdateWidget',1)[1].split('void _lockSection',1)[0]
        self.assertIn('_privacyShield = true;',callback)
        self.assertIn('_workflowSearchController.clear()',callback)
    def test_staging_check_rolls_back_and_never_posts(self):
        self.assertIn('BEGIN;',STAGING)
        self.assertIn('ROLLBACK;',STAGING)
        self.assertNotIn('SELECT public.gs_financial_allocate_and_journal_verified_prepaid(',STAGING)
    def test_privacy_reveal_requires_server_check(self):
        callback=SHELL.split('void _unlockAndRecheck',1)[1].split('Widget _privacyLocked',1)[0]
        self.assertIn('final check = _checkAccess();',callback)
        self.assertIn('if (allowed)',callback)

if __name__=='__main__': unittest.main()
