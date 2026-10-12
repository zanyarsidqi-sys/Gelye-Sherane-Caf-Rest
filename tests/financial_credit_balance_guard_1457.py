"""Upgrade 1457: offline source contract regression; not a PostgreSQL test."""
from pathlib import Path
import zipfile

archive = Path(__import__('sys').argv[1])
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    sql = z.read('gelye_cafe_rest/supabase/migrations/20261012_1457_credit_charge_balance_guard.sql').decode()
    for token in ('before insert on public.gs_credit_account_journal', 'for share',
                  'outstanding_iqd is distinct from new.outstanding_after_iqd',
                  'source_request_id = new.source_request_id', 'raise exception',
                  'revoke all on function', "new.event_kind <> 'charge'"):
        assert token in sql, token
    assert 'update public.gs_motel_food_finance_invoices' not in sql
    assert 'insert into public.gs_unified_payment_ledger' not in sql
print('PASS: archive integrity and 9 source-contract assertions')
