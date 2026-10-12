import pathlib, unittest, zipfile

class SharedSecurityRegression(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.root=pathlib.Path(__file__).resolve().parents[1]
        cls.shell=(cls.root/'lib/shared/section_shell.dart').read_text()
    def test_periodic_access_recheck(self):
        self.assertIn('Timer.periodic(_accessRecheckInterval',self.shell)
        self.assertIn('Duration(minutes: 10)',self.shell)
    def test_no_access_check_when_hidden(self):
        self.assertIn('if (!mounted || _privacyShield) return;',self.shell)
    def test_handover_cleared_before_recheck(self):
        self.assertIn('_sessionHandoverChecks.clear();\n      _refreshAccess();',self.shell)
    def test_timer_cancelled(self):
        self.assertIn('_periodicAccessRecheck?.cancel();',self.shell)
    def test_fail_closed_revalidation(self):
        self.assertIn('_privacyShield = true;\n      _accessGeneration++;',self.shell)
    def test_registered_sections(self):
        ids=['dashboard','tables','table_orders','motel_orders','kitchen','menu','products_inventory','customers','cost','revenue','invoices_payments','employees','maintenance','notifications','reports','backup_restore','settings_rules','analytics','action_center','pay_now','discount_management','payments_management','credit_management','device_layout_mode','appearance_dark_mode','dictionary_language_management','websites_management','general_information','invoice_design_customization','security_access_control','offline_mode_synchronization','app_publishing_updates','system_health_monitoring','test_mode_real_mode','nargile_management']
        self.assertEqual(len(ids),35)
        for ident in ids:self.assertIn("'"+ident+"'",self.shell)

if __name__=='__main__':unittest.main()
