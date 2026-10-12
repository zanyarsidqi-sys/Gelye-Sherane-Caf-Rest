import pathlib, unittest
p=pathlib.Path(__file__).resolve().parents[1]/'supabase/migrations/20261012_1463_provider_attested_prepaid_allocation.sql'
s=p.read_text()
class PrepaidContract(unittest.TestCase):
 def test_source_attestation(self):
  for token in ['provider_transaction_id','provider_proof_sha256','verified_by_service','unique(provider,provider_transaction_id)','revoke all on public.gs_motel_prepaid_verified_receipts']:
   with self.subTest(token=token): self.assertIn(token,s)
 def test_allocation(self):
  for token in ['for update','already_allocated','gs_staff_check_motel_food_finance_invoice','gs_motel_food_cash_settlements','gs_motel_prepaid_invoice_allocations','invoice_settled','unified_ledger_posted','dashboard_certified']:
   with self.subTest(token=token): self.assertIn(token,s)
 def test_immutability(self):
  self.assertIn('before update or delete',s)
if __name__=='__main__':unittest.main()
