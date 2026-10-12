"""Offline regression checks for the final deployed replacement RPC definitions.
These checks are static; staging PostgreSQL/Supabase execution is still required.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MIGRATIONS = ROOT / 'supabase' / 'migrations'


def last_function(name):
    files = sorted(MIGRATIONS.glob('*.sql'))
    found = []
    pattern = re.compile(r'create\s+or\s+replace\s+function\s+public\.' + re.escape(name) + r'\s*\(', re.I)
    for file in files:
        content = file.read_text(encoding='utf-8')
        for match in pattern.finditer(content):
            # Function declarations in this project use dollar-quoted bodies.
            end = content.find('end $$;', match.end())
            if end < 0:
                raise AssertionError(f'Unterminated function in {file.name}')
            found.append((file.name, content[match.start():end + len('end $$;')].lower()))
    if not found:
        raise AssertionError(f'Missing function {name}')
    return found[-1]


class ReplacementFinalDefinitionTests(unittest.TestCase):
    def test_final_quote_and_commit_are_from_upgrade_557(self):
        for fn in ('gs_quote_unaccepted_table_replacement', 'gs_replace_unaccepted_table_item'):
            filename, body = last_function(fn)
            self.assertIn('_557_', filename, (fn, filename))
            self.assertIn("gs_can_access('table_orders','can_edit')", body)
            self.assertIn('for update', body)
            self.assertIn('previous product replacement is awaiting kitchen acknowledgment', body)
            self.assertIn('gs_item_payment_allocations', body)
            self.assertIn('gs_cafe_order_station_ticket_items', body)
            self.assertIn('case when v_mode then tourism_price_iqd else normal_price_iqd end', body)

    def test_commit_requires_confirmed_server_price_and_records_dispatch(self):
        _, body = last_function('gs_replace_unaccepted_table_item')
        for token in ('p_confirmed_new_unit_price_iqd', 'p_confirmed_new_unit_price_iqd <> v_new_price',
                      'gs_order_revision_events', 'gs_order_revision_dispatch',
                      "'kitchen_revision'", "'customer_update'", "'employee_notification'"):
            self.assertIn(token, body)

    def test_quote_is_read_only(self):
        _, body = last_function('gs_quote_unaccepted_table_replacement')
        self.assertNotRegex(body, r'\b(insert\s+into|update\s+public\.|delete\s+from)\b')

    def test_no_legacy_public_grant_in_latest_migration(self):
        sql = (MIGRATIONS / '20261010_557_replacement_input_consistency.sql').read_text().lower()
        self.assertIn('revoke execute on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text) from authenticated', sql)
        self.assertIn('grant execute on function public.gs_replace_unaccepted_table_item(bigint,bigint,bigint,bigint,text,bigint) to authenticated', sql)

    def test_ui_invokes_quote_and_commit(self):
        ui = (ROOT / 'lib/sections/table_orders.dart').read_text()
        self.assertIn('gs_quote_unaccepted_table_replacement', ui)
        self.assertIn('gs_replace_unaccepted_table_item', ui)


if __name__ == '__main__':
    unittest.main()
