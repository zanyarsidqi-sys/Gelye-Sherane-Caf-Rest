from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = (ROOT / 'lib/shared/live_kitchen_panel.dart').read_text()

def test_kitchen_queue_no_longer_silently_limits_to_100():
    assert '.limit(100)' not in SRC
    assert '.range(page * pageSize, (page + 1) * pageSize - 1)' in SRC
    assert 'rows.length < pageSize' in SRC

def test_stable_pagination_and_cap_warning():
    assert ".order('created_at', ascending: false)" in SRC
    assert ".order('id', ascending: false)" in SRC
    assert '_queueMayBeTruncated' in SRC
    assert 'Kitchen queue may be incomplete' in SRC

def test_pagination_does_not_shift_order_index():
    assert 'visible[index - 1 - (_queueMayBeTruncated ? 1 : 0)]' in SRC
