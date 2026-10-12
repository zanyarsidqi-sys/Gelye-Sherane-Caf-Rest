from pathlib import Path

SRC = Path(__file__).resolve().parents[2] / 'lib/sections/table_orders.dart'
s = SRC.read_text()

def test_history_cannot_display_after_employee_change():
    segment = s.split('Future<void> _showReplacementReceiptHistory()', 1)[1].split('Future<void> _lookupReplacementRequestId', 1)[0]
    assert 'final initiatingUser = Supabase.instance.client.auth.currentUser?.id;' in segment
    assert 'currentUser?.id != initiatingUser' in segment

def test_manual_lookup_rechecks_employee_before_receipt_and_clear():
    segment = s.split('Future<void> _lookupReplacementRequestId', 1)[1].split('int _boardRequestVersion', 1)[0]
    assert segment.count('currentUser?.id != initiatingUser') >= 4
    assert 'final actorId = initiatingUser;' in segment

def test_mutation_rechecks_employee_after_rpc():
    segment = s.split("result = await client.rpc('gs_replace_unaccepted_table_item'", 1)[1].split('Future<void> editQuantity', 1)[0]
    assert segment.count('client.auth.currentUser?.id != actorId') >= 3
    assert 'TableReplacementRecovery.clear(actorId, requestId)' in segment
