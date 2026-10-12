from pathlib import Path

SRC = Path(__file__).resolve().parents[2] / 'lib/shared/live_kitchen_panel.dart'

def test_server_filters_before_paging():
    source = SRC.read_text()
    assert "query.inFilter('status', ['new', 'preparing', 'ready'])" in source
    assert "query.eq('status', requestedStatus)" in source
    assert source.index("query.inFilter('status'") < source.index('.range(page * pageSize')

def test_changing_filter_reloads_from_database():
    source = SRC.read_text()
    assert '_statusFilter = filter;' in source
    assert '_orders = _load();' in source
    assert '_itemRequests.clear();' in source

def test_pagination_and_warning_remain():
    source = SRC.read_text()
    assert 'const maxPages = 10;' in source
    assert '_queueMayBeTruncated = true;' in source
    assert 'Kitchen queue may be incomplete' in source
