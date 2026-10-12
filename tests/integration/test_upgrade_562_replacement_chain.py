"""Static cross-version contracts; these do not replace database concurrency tests."""
from pathlib import Path
import re
ROOT = Path(__file__).resolve().parents[2]
M = ROOT / 'supabase/migrations'
DART = (ROOT / 'lib/sections/table_orders.dart').read_text()
def sql(n):
    return next(M.glob(f'20261010_{n}_*.sql')).read_text().lower()
def test_quote_server_prices_and_mode():
    s=sql(557)
    assert 'tourism_mode' in s and 'new_unit_price_iqd' in s
    assert 'quantity' in s and 'difference_iqd' in s
def test_price_quantity_mode_commit_chain():
    assert 'p_confirmed_new_unit_price_iqd' in sql(538)
    assert 'p_expected_quantity' in sql(560) and 'for update' in sql(560)
    assert 'p_expected_tourism_mode' in sql(561) and 'for update' in sql(561)
    assert 'is distinct from p_expected_tourism_mode' in sql(561)
def test_previous_client_entrypoints_revoked():
    for n,arity in [(554,'bigint,bigint,bigint,bigint,text'),(560,'bigint,bigint,bigint,bigint,text,bigint'),(561,'bigint,bigint,bigint,bigint,text,bigint,integer')]:
        assert re.search(re.escape(arity + ')') + r'\s+from\s+public,\s*anon,\s*authenticated', sql(n))
    assert 'bigint,bigint,bigint,bigint,text,bigint,integer,boolean) to authenticated' in sql(561)
def test_ui_rejects_malformed_quote_and_submits_all_confirmations():
    for phrase in ["quoteRaw['tourism_mode'] is! bool", "quotedQuantity != quantity", "quotedIqd('difference_iqd')", "'p_expected_quantity': quotedQuantity", "'p_expected_tourism_mode': quoteRaw['tourism_mode']", "'p_confirmed_new_unit_price_iqd': confirmedPrice"]:
        assert phrase in DART
def test_kitchen_and_financial_guards_present():
    assert 'gs_replace_unaccepted_table_item' in sql(556)
    assert 'kitchen' in sql(556)
    assert 'gs_can_access' in sql(561)
    assert 'revoke all' in sql(554)
