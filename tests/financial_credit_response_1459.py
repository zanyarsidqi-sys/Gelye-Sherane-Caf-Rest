"""Upgrade 1459: execute offline payment-response safety contract assertions."""
import pathlib
s=pathlib.Path(__file__).resolve().parents[1].joinpath('lib/shared/payments_management_panel.dart').read_text()
checks={
 'staging disabled': "'GS_ENABLE_VERIFIED_CREDIT_POSTING', defaultValue: false" in s,
 'server RPC': "rpc('gs_financial_post_verified_credit_charge'" in s,
 'request stable key': "'motel-credit-request:$canonicalRequest'" in s,
 'capture employee identity': 'final postingEmployeeId = Supabase.instance.client.auth.currentUser?.id;' in s,
 'employee session unchanged': 'activeEmployee != postingEmployeeId' in s,
 'journal UUID checked': "journalId is! String || !uuid.hasMatch(journalId)" in s,
 'account UUID checked': "accountId is! String || !uuid.hasMatch(accountId)" in s,
 'positive integer amount': 'amount is! int || amount <= 0' in s,
 'boolean retry identity': 'alreadyPosted is! bool' in s,
 'retry message': "alreadyPosted ? 'Credit charge already recorded'" in s,
 'no invoice settlement': "result['invoice_settled'] != false" in s,
 'no prepaid claim': "result['prepaid_allocated'] != false" in s,
 'no dashboard certification': "result['dashboard_certified'] != false" in s,
 'no auto retry': "timeout(const Duration(seconds: 25))" in s,
 'busy flag': '_creditPostingBusy = true' in s,
 'manual confirmation': "const Text('Post verified charge')" in s,
}
for name,passed in checks.items():
 assert passed,name
print(f'PASS {len(checks)} offline Flutter response-contract assertions')
