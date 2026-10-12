import pathlib, unittest, zipfile

class UpgradeContracts(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.zip_path=pathlib.Path(__file__).resolve().parents[3] / 'unused'
        cls.shell=pathlib.Path(__file__).resolve().parents[1] / 'lib/shared/section_shell.dart'
        cls.sql=pathlib.Path(__file__).resolve().parents[1] / 'supabase/migrations/20261012_1476_approved_identity_read.sql'
    def test_manual_permission_refresh(self):
        s=self.shell.read_text(); self.assertIn("tooltip: 'Recheck employee access'",s);self.assertIn('onPressed: _refreshAccess',s)
    def test_section_filter_reset(self):
        s=self.shell.read_text();self.assertIn("_search = '';",s);self.assertIn('oldWidget.sectionId != widget.sectionId',s)
    def test_independent_approval_read(self):
        s=self.sql.read_text();self.assertIn('gs_motel_cafe_identity_approvals',s);self.assertIn('v_mapping.verified_by=v_approval.approved_by',s)
    def test_read_does_not_certify(self):
        s=self.sql.read_text();self.assertIn("'unified_ledger_posted',false",s);self.assertIn("'dashboard_certified',false",s);self.assertNotIn('update public.',s.lower())
if __name__=='__main__':unittest.main()
