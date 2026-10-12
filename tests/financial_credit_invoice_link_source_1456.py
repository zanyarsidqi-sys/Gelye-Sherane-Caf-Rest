#!/usr/bin/env python3
"""Source contract checks; not a PostgreSQL runtime test."""
from pathlib import Path
sql=Path(__file__).resolve().parents[1].joinpath('supabase/migrations/20261012_1456_credit_invoice_link_source_integrity.sql').read_text()
checks={
 'source request pending':"v_request.status <> 'pending'",
 'positive charge':"new.delta_outstanding_iqd<=0",
 'active barcode':"v_registry.account_status <> 'active'",
 'verified account link':"v_registry_link.link_status <> 'verified'",
 'account matches journal':"v_registry_link.account_id is distinct from new.account_id",
 'verified customer':"v_customer.verification_status <> 'verified'",
 'matching account reference':"v_account.account_reference is distinct from v_registry.account_reference",
 'invoice row lock':"for update",
 'invoice line count':"v_lines_count <> v_invoice.source_count",
 'invoice line sum':"v_lines_sum <> v_invoice.total_iqd",
 'draft collision':"id<>v_draft.id",
 'cash collision':"gs_motel_food_cash_settlements",
 'durable linkage':"insert into public.gs_financial_credit_invoice_charge_links",
 'no settlement claim':"not a prepaid allocation, invoice settlement or dashboard certification",
}
for name,term in checks.items():
 assert term.lower() in sql.lower(),f'Missing {name}'
print(f'PASS {len(checks)} source contract assertions')
