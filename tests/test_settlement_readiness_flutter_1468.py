import unittest, pathlib, zipfile

class SettlementReadinessFlutterContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.archive=pathlib.Path(__file__).resolve().parents[1]
        cls.dart=(cls.archive/'lib/shared/payments_management_panel.dart').read_text()
        cls.sql=(cls.archive/'supabase/diagnostics/settlement_smoke_1468.sql').read_text()
    def test_rpc_wired(self):
        self.assertIn("'gs_financial_motel_invoice_settlement_readiness'",self.dart)
        self.assertIn("'p_invoice_id': invoiceId.toLowerCase()",self.dart)
    def test_fail_closed(self):
        for item in ["report['settlement_ready'] != false", "report['invoice_settled'] != false", "report['unified_ledger_posted'] != false", "report['dashboard_certified'] != false"]:
            self.assertIn(item,self.dart)
    def test_session_and_busy(self):
        self.assertIn('if (_settlementReadinessBusy || !mounted) return;',self.dart)
        self.assertIn('currentUser?.id != employeeId',self.dart)
    def test_read_only_ui(self):
        self.assertIn('Inspect motel invoice settlement readiness (read-only)',self.dart)
        self.assertIn('No invoice-paid status, unified ledger entry or Dashboard IQD total is certified',self.dart)
    def test_staging_sql_is_read_only(self):
        self.assertIn('rollback;',self.sql.lower())
        self.assertIn('has_function_privilege',self.sql)
        self.assertIn('has_table_privilege',self.sql)

if __name__=='__main__': unittest.main()
