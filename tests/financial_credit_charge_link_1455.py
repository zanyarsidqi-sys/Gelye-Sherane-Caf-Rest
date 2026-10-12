#!/usr/bin/env python3
"""Source regression assertions for upgrade 1455; does not simulate PostgreSQL."""
import pathlib
s=pathlib.Path(__file__).resolve().parents[1].joinpath('supabase/migrations/20261012_1455_credit_invoice_charge_link.sql').read_text()
checks={
 'invoice uniqueness':'finance_invoice_id uuid not null unique' in s,
 'request uniqueness':'credit_request_id uuid not null unique' in s,
 'journal uniqueness':'credit_journal_id uuid not null unique' in s,
 'positive amount':'check(amount_iqd > 0)' in s,
 'RLS enabled':'enable row level security' in s,
 'table grants revoked':'revoke all on public.gs_financial_credit_invoice_charge_links' in s,
 'charge only':"new.event_kind <> 'charge'" in s,
 'request matches journal':'v_request.amount_iqd is distinct from new.delta_outstanding_iqd' in s,
 'draft matches journal':'v_draft.amount_iqd is distinct from new.delta_outstanding_iqd' in s,
 'invoice locked':'where id=v_draft.finance_invoice_id for update' in s,
 'unpaid only':"v_invoice.payment_status <> 'unpaid'" in s,
 'invoice amount':'v_invoice.total_iqd is distinct from new.delta_outstanding_iqd' in s,
 'cash collision':'Cash and credit settlement collision' in s,
 'invoice duplicate':'Invoice already has a recorded credit charge' in s,
 'journal trigger':'after insert on public.gs_credit_account_journal' in s,
 'immutable trigger':'before update or delete on public.gs_financial_credit_invoice_charge_links' in s,
 'no paid transition':"update public.gs_motel_food_finance_invoices" not in s.lower(),
 'no legacy bridge change':'update public.gs_motel_finance_source_bridge' not in s.lower(),
 'no ledger fabrication':'insert into public.gs_unified_payment_ledger' not in s.lower(),
 'no dashboard certification':'certified_unpaid_iqd' not in s.lower(),
}
for name,ok in checks.items():
 print(('PASS' if ok else 'FAIL')+' '+name)
assert all(checks.values()),'source regression failure'
print(f'PASS {len(checks)}/{len(checks)} source checks (not DB tests)')
