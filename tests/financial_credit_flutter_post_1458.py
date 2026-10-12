# Upgrade 1458: offline source-contract tests; not a live Supabase test.
import pathlib, re
s=pathlib.Path(__file__).resolve().parents[1].joinpath('lib/shared/payments_management_panel.dart').read_text()
checks={
 'staging flag defaults off': "'GS_ENABLE_VERIFIED_CREDIT_POSTING', defaultValue: false" in s,
 'verified request not invoice': 'Credit verification request UUID' in s,
 'stable retry key': "'motel-credit-request:$canonicalRequest'" in s,
 'server RPC': "rpc('gs_financial_post_verified_credit_charge'" in s,
 'server-side authorization retained': "Supabase.instance.client.auth.currentUser == null" in s,
 'requires explicit confirmation': "confirmed != true" in s,
 'rejects unverified invoice settlement': "result['invoice_settled'] != false" in s,
 'rejects unverified prepaid': "result['prepaid_allocated'] != false" in s,
 'rejects certified totals': "result['dashboard_certified'] != false" in s,
 'rejects malformed response': 'if (raw is! Map)' in s,
 'prevents double-click posting': '_creditPostingBusy ? null : _postVerifiedCreditRequest' in s,
 'preserves dashboard deep link': "widget.initialFocus == 'pending'" in s,
}
for name,ok in checks.items():
 print(('PASS' if ok else 'FAIL')+' '+name)
assert all(checks.values())
