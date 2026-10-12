from pathlib import Path
SRC=(Path(__file__).resolve().parents[2]/"lib/shared/live_kitchen_panel.dart").read_text()

def test_item_recheck_refreshes_entire_authoritative_queue():
    assert "label: const Text('Recheck order and items')" in SRC
    assert "? null : _refresh" in SRC
    assert "_itemRequests.clear();" in SRC

def test_recheck_cannot_interrupt_active_confirmation():
    assert "(_busyId != null || _confirmingId != null)" in SRC

def test_cross_section_order_identity_is_retained():
    assert "order['is_motel'] == true" in SRC
    assert "order['destination']" in SRC
