#!/usr/bin/env python3
"""Offline structural regression; NOT Flutter compile or PostgreSQL validation."""
from pathlib import Path
s=Path(__file__).resolve().parents[1].joinpath('lib/shared/payments_management_panel.dart').read_text()
a=s.index('  Future<void> _postVerifiedCreditRequest() async {')
b=s.index('  Future<void> _inspectCreditInvoiceTrace()',a)
f=s[a:b]
assert f.index('setState(() => _creditPostingBusy = true);') < f.index('await showDialog')
assert f.count('setState(() => _creditPostingBusy = true);') == 1
assert 'if (_creditPostingBusy' not in f or '_creditPostingBusy || !mounted' in f
assert f.index("currentUser?.id != postingEmployeeId") < f.index(".rpc('gs_financial_post_verified_credit_charge'")
assert "'p_idempotency_key': 'motel-credit-request:$canonicalRequest'" in f
assert "result['invoice_settled'] != false" in f
assert "result['prepaid_allocated'] != false" in f
assert "result['dashboard_certified'] != false" in f
assert 'finally {' in f and 'setState(() => _creditPostingBusy = false)' in f
assert "'GS_ENABLE_VERIFIED_CREDIT_POSTING', defaultValue: false" in s
print('PASS: 10 offline structural checks; live staging and Flutter compilation NOT performed')
