from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / 'lib/shared/live_kitchen_panel.dart'

def test_filter_initialized_before_initial_query():
    source = SOURCE.read_text()
    assert source.index("String _statusFilter = 'active';") < source.index('late Future<List<Map<String, dynamic>>> _orders = _load();')

def test_kitchen_query_filters_before_pagination():
    source = SOURCE.read_text()
    assert source.index("query.inFilter('status'") < source.index('.range(page * pageSize')

def test_refresh_clears_cached_items():
    source = SOURCE.read_text()
    assert '_itemRequests.clear();' in source
