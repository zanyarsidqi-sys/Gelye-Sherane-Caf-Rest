from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'lib/shared/live_kitchen_panel.dart').read_text()
def test_equal_timestamps_have_stable_id_tiebreaker():
    assert 'if (timeComparison != 0) return timeComparison;' in SOURCE
    assert 'leftId.compareTo(rightId)' in SOURCE
    assert 'rightId.compareTo(leftId)' in SOURCE
def test_existing_filters_and_handover_remain():
    for status in ("'active'", "'new'", "'preparing'", "'ready'", "'served'", "'cancelled'"):
        assert status in SOURCE
    assert "rpc('gs_update_kitchen_status'" in SOURCE
    assert 'Confirm order handover' in SOURCE
