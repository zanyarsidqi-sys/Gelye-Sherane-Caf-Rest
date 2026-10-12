import unittest, zipfile, sys
from pathlib import Path

class FinancialSettlementSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.archive=zipfile.ZipFile(__import__('os').environ['PROJECT_ZIP'])
        cls.files={n:cls.archive.read(n).decode('utf-8',errors='replace') for n in cls.archive.namelist() if n.endswith('.sql') and '/migrations/' in n}
        cls.new=next(v for k,v in cls.files.items() if k.endswith('_invoice_settlement_readiness.sql'))
        cls.all='\n'.join(cls.files.values())
    def test_no_fabricated_crosswalk(self): self.assertIn("'numeric_order_identity_verified',false",self.new)
    def test_no_certified_amount(self): self.assertIn("'certified_unpaid_iqd',null",self.new)
    def test_no_certified_complete(self): self.assertIn("'verified_complete',false",self.new)
    def test_prepaid_not_invented(self): self.assertIn("'prepaid_allocated',false",self.new)
    def test_unified_not_invented(self): self.assertIn("'unified_ledger_settled',false",self.new)
    def test_read_permissions(self): self.assertIn("gs_can_access('motel_orders','can_view')",self.new)
    def test_finance_permissions(self): self.assertIn("gs_can_access('invoices_payments','can_view')",self.new)
    def test_invoice_lines(self): self.assertIn('gs_motel_food_finance_invoice_lines',self.new)
    def test_bridge(self): self.assertIn('gs_motel_finance_source_bridge',self.new)
    def test_cash(self): self.assertIn('gs_motel_food_cash_settlements',self.new)
    def test_credit(self): self.assertIn('gs_credit_account_journal',self.new)
    def test_crosswalk(self): self.assertIn('gs_financial_crosswalk_evidence',self.new)
    def test_collision(self): self.assertIn("'cash_credit_collision'",self.new)
    def test_cash_consistency(self): self.assertIn("'cash_status_consistent'",self.new)
    def test_no_mutation(self):
        low=self.new.lower()
        for keyword in ['insert into','update public.','delete from','alter table']:
            self.assertNotIn(keyword,low)
    def test_credit_posting_retained(self): self.assertIn('gs_financial_post_verified_credit_charge',self.all)
    def test_cash_posting_retained(self): self.assertIn('gs_staff_settle_motel_food_cash',self.all)
    def test_trigger_retained(self): self.assertIn('gs_financial_credit_charge_source_guard',self.all)
    def test_crosswalk_review_retained(self): self.assertIn('gs_financial_review_crosswalk_evidence',self.all)
    def test_revoke_and_grant(self):
        self.assertIn('revoke all on function',self.new)
        self.assertIn('grant execute on function',self.new)

if __name__=='__main__':
    unittest.main(argv=[sys.argv[0]],verbosity=2)
