"""Offline consistency preflight; not a substitute for applying migrations in staging."""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
MIGRATIONS = ROOT / 'supabase' / 'migrations'


def run_checks():
    files = sorted(MIGRATIONS.glob('*.sql'))
    checks = []
    def check(name, condition):
        checks.append({'name': name, 'passed': bool(condition)})

    def latest_definition(function_name):
        pattern = re.compile(r'create\s+or\s+replace\s+function\s+public\.' + re.escape(function_name) + r'\s*\(', re.I)
        matches = [(f.name, f.read_text(encoding='utf-8')) for f in files if pattern.search(f.read_text(encoding='utf-8'))]
        return matches[-1] if matches else ('', '')

    status_file, status = latest_definition('gs_update_kitchen_status')
    guard_file, guard = latest_definition('gs_guard_served_order_items')
    check('status function deployed from migration 1142 or later', '1143' in status_file)
    check('status RPC enforces employee permission', "gs_can_access('kitchen', 'can_edit')" in status)
    check('status RPC locks parent order', bool(re.search(r'from\s+public\.gs_orders\s+where\s+id\s*=\s*p_order_id\s+for\s+update', status, re.I)))
    check('status RPC rejects empty order', 'v_item_count = 0' in status)
    check('status RPC checks exact line totals', 'line_total_iqd::numeric <> quantity::numeric * unit_price_iqd::numeric' in status)
    check('status RPC restricts anonymous execution', bool(re.search(r'revoke\s+all\s+on\s+function\s+public\.gs_update_kitchen_status\(bigint,text\)\s+from\s+public', status, re.I)))
    check('guard function defined after status validation', '1144' in guard_file)
    check('guard serializes item writes on parent', bool(re.search(r'from\s+public\.gs_orders\s+where\s+id\s*=\s*v_order_id\s+for\s+update', guard, re.I)))
    check('guard rejects changes to served orders', "v_status = 'served'" in guard)
    check('guard rejects moving items between orders', 'new.order_id is distinct from old.order_id' in guard)
    check('guard trigger handles insert update delete', bool(re.search(r'before\s+insert\s+or\s+update\s+or\s+delete\s+on\s+public\.gs_order_items', guard, re.I)))
    check('guard trigger is revoked from clients', bool(re.search(r'revoke\s+all\s+on\s+function\s+public\.gs_guard_served_order_items\(\)\s+from\s+public,\s*anon,\s*authenticated', guard, re.I)))
    return checks


if __name__ == '__main__':
    checks = run_checks()
    print(json.dumps({'passed': sum(c['passed'] for c in checks), 'total': len(checks), 'checks': checks}, indent=2))
    raise SystemExit(0 if all(c['passed'] for c in checks) else 1)
