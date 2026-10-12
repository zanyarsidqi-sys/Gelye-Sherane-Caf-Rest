# Upgrade 1453 — 20 source regression assertions (static, not PostgreSQL tests)
# Run: python3 tests/financial_credit_source_regression_1453.py
import pathlib, zipfile, sys
archive=pathlib.Path(sys.argv[1]) if len(sys.argv)>1 else None
if archive:
    with zipfile.ZipFile(archive) as z:
        names=z.namelist()
        migration=next(n for n in names if n.endswith('20261012_1453_credit_invoice_row_serialization.sql'))
        sql=z.read(migration).decode()
else:
    sql=pathlib.Path(__file__).resolve().parents[1].joinpath('supabase/migrations/20261012_1453_credit_invoice_row_serialization.sql').read_text()
checks={
 'definer guard remains': 'security invoker' in sql,
 'trigger function remains': 'returns trigger' in sql,
 'invoice exclusive row lock': 'where id=d.finance_invoice_id for update;' in sql,
 'no shared invoice lock': 'where id=d.finance_invoice_id for share;' not in sql,
 'request row lock': 'where id=new.source_request_id for share' in sql,
 'invoice unpaid check': "f.payment_status <> 'unpaid'" in sql,
 'invoice source count': 'f.source_count<=0' in sql,
 'invoice source total': 'v_total <> f.total_iqd' in sql,
 'invoice source count match': 'v_count <> f.source_count' in sql,
 'cash settlement collision': 'gs_motel_food_cash_settlements' in sql,
 'competing drafts': 'Conflicting invoice payment draft' in sql,
 'competing pending requests': 'Competing pending credit verification request' in sql,
 'prior invoice charge': 'Invoice already charged in credit journal' in sql,
 'active registry': "r.account_status<>'active'" in sql,
 'verified registry link': "l.link_status <> 'verified'" in sql,
 'registry verified by': 'l.verified_by is null' in sql,
 'matching account': 'l.account_id<>new.account_id' in sql,
 'verified customer': "c.verification_status <> 'verified'" in sql,
 'bounded account balance': 'a.outstanding_iqd > a.credit_limit_iqd' in sql,
 'duplicate request charge': 'Credit request already charged' in sql,
}
for name,passed in checks.items():
    print(('PASS' if passed else 'FAIL')+' '+name)
print(f'{sum(checks.values())}/{len(checks)} source checks passed')
sys.exit(0 if all(checks.values()) else 1)
