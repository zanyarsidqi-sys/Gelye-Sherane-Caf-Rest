from pathlib import Path
S=(Path(__file__).resolve().parents[2]/'lib/shared/live_kitchen_panel.dart').read_text()

def test_item_fetch_rejects_stale_generation():
    assert 'required int expectedGeneration' in S
    assert 'expectedGeneration != _loadGeneration' in S
    assert 'employeeId != _loadedUserId' in S

def test_both_item_load_paths_pass_generation():
    assert '_loadItems(id, expectedGeneration: queueGeneration)' in S
    assert '_loadItems(id, expectedGeneration: _loadGeneration)' in S

def test_queue_refresh_invalidates_cached_items():
    start=S.index('void _refresh()')
    assert '_itemRequests.clear();' in S[start:S.index('Future<void> _confirmAndAdvance',start)]
