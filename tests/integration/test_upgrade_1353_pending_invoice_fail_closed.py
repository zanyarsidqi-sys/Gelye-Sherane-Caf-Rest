from pathlib import Path
import unittest

class PendingInvoiceDiagnosticContract(unittest.TestCase):
    def test_fail_closed_and_read_only(self):
        root = Path(__file__).resolve().parents[2]
        sql = (root / 'supabase/migrations/20261012_1353_pending_invoice_fail_closed_diagnostic.sql').read_text()
        for token in ['v_invoice.payment_status is null', 'v_invoice.total_iqd <= 0',
                      'v_cash_count > 1', 'v_invalid_cash > 0',
                      'amount_iqd is null or amount_iqd <= 0',
                      "'collection_authorized',false", 'security definer',
                      'revoke all on function', 'to authenticated']:
            self.assertIn(token, sql)
        self.assertNotIn('insert into ', sql.lower())
        self.assertNotIn('update public.', sql.lower())

if __name__ == '__main__': unittest.main()
