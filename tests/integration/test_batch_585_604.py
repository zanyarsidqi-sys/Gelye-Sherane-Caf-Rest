from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
K = (ROOT / 'lib/shared/live_kitchen_panel.dart').read_text()
R = (ROOT / 'lib/shared/live_records_panel.dart').read_text()

def test_kitchen_session_and_race_guards():
    assert '_isCurrentEmployee' in K and 'employeeId != _loadedUserId' in K
    assert 'generation != _loadGeneration' in K
    assert 'if (_busyId != null) return;' in K

def test_kitchen_order_and_sort_guards():
    assert 'id == null || id <= 0' in K
    assert 'leftId.compareTo(rightId)' in K

def test_records_pagination_and_scope():
    assert 'const pageSize = 250;' in R
    assert 'const maxPages = 20;' in R
    assert "query.eq('is_motel', widget.kind == 'motel')" in R
    assert ".order('id', ascending: false)" in R

def test_records_session_and_limit():
    assert 'generation != _loadGeneration' in R
    assert '_resultsMayBeTruncated = true' in R
    assert 'itemCount: filtered.length + (_resultsMayBeTruncated ? 1 : 0)' in R

def test_all_twenty_documented():
    log = (ROOT / 'BATCH_UPGRADES_585_TO_604.md').read_text()
    for i in range(585, 605):
        assert f'{i}:' in log
