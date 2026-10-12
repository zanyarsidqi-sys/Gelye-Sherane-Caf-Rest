from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / 'lib/sections/table_orders.dart'

def test_cross_device_lookup_uses_scoped_status_endpoint():
    source = SOURCE.read_text()
    block = source.split('Future<void> _lookupReplacementRequestId()', 1)[1].split('  // A late response', 1)[0]
    assert "'gs_table_replacement_request_status'" in block
    assert "'p_request_id': requestId" in block
    assert "gs_replace_unaccepted_table_item" not in block

def test_absent_receipt_is_not_safe_retry():
    source = SOURCE.read_text()
    assert 'This does not prove that the transaction failed' in source
    assert 'Do not repeat the replacement' in source

def test_uuid_validation_and_board_entry():
    source = SOURCE.read_text()
    assert "validUuid.hasMatch(requestId)" in source
    assert "onPressed: _lookupReplacementRequestId" in source
