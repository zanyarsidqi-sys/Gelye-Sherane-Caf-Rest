import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MIG=(ROOT/'supabase/migrations/20261012_1467_settlement_readiness.sql').read_text()
SMOKE=(ROOT/'supabase/diagnostics/settlement_staging_1467.sql').read_text()
class SettlementReadinessContract(unittest.TestCase):
 def test_fail_closed(self):
  for token in ('settlement_ready', 'unified_ledger_posted', 'dashboard_certified', 'authoritative_order_crosswalk_and_unified_ledger_unverified'):
   self.assertIn(token,MIG)
 def test_permissions(self):
  for token in ('auth.uid()','gs_can_access','revoke all','to authenticated'):
   self.assertIn(token,MIG)
 def test_no_write_sql(self):
  self.assertNotRegex(MIG.lower(),r'\b(insert into|update public\.|delete from|truncate)\b')
 def test_staging_rollback(self):
  self.assertIn('rollback;',SMOKE.lower())
  self.assertIn('has_function_privilege',SMOKE)
if __name__=='__main__': unittest.main()
