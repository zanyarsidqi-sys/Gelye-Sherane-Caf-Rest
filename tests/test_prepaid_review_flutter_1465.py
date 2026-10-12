import unittest,zipfile
from pathlib import Path
class Upgrade1465Tests(unittest.TestCase):
 def test_source_contract(self):
  root=Path(__file__).resolve().parents[1]
  sql=(root/'supabase/migrations/20261012_1465_prepaid_review_flutter.sql').read_text()
  dart=(root/'lib/shared/payments_management_panel.dart').read_text()
  for s in ['auth.uid() is null','gs_can_access','gs_motel_prepaid_verified_receipts','gs_staff_check_motel_food_finance_invoice','gs_motel_food_cash_settlements','gs_financial_credit_invoice_charge_links','dashboard_certified',"grant execute on function"]: self.assertIn(s,sql)
  for s in ['GS_ENABLE_VERIFIED_PREPAID_ALLOCATION','defaultValue: false','gs_financial_review_verified_prepaid_receipt','gs_financial_allocate_verified_motel_prepaid','_prepaidAllocationBusy','invoice_settled','unified_ledger_posted','currentUser?.id']: self.assertIn(s,dart)
if __name__=='__main__': unittest.main()
