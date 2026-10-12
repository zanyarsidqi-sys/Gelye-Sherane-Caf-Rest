from pathlib import Path

source = Path(__file__).resolve().parents[2] / 'lib/sections/table_orders.dart'
s = source.read_text()
assert "result['difference_iqd'] is! int" in s
assert "result['difference_iqd'] != quotedIqd('difference_iqd')" in s
assert 'check its history before attempting another replacement' in s
assert 'await refresh();' in s
print('Upgrade 563 static response-guard checks passed')
