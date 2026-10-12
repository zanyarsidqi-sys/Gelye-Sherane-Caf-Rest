from pathlib import Path
SRC = (Path(__file__).resolve().parents[2] / 'lib/sections/table_orders.dart').read_text()

def test_lookup_reconciles_only_exact_pending_identity():
    assert "pending['request_id'] == requestId" in SRC
    assert "_validId(details!['order_item_id']) == pending['order_item_id']" in SRC
    assert "_validId(details['product_id']) == pending['product_id']" in SRC
    assert "details['difference_iqd'] == pending['expected_difference_iqd']" in SRC

def test_lookup_clears_only_after_verified_commit():
    assert "final resolvesPending = committed && pending != null && actorId != null" in SRC
    assert "if (resolvesPending) {\n        await TableReplacementRecovery.clear(actorId, requestId);" in SRC
    assert "setState(() => _pendingReplacement = null);\n        await refresh();" in SRC

def test_unmatched_receipts_keep_pending_recovery():
    assert "final pending = _pendingReplacement;" in SRC
    assert "No committed receipt was found for this request and employee." in SRC
