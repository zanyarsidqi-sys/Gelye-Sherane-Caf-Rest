from pathlib import Path
SRC = (Path(__file__).resolve().parents[2] /
       'lib/shared/live_kitchen_panel.dart').read_text()

def test_rejected_rpc_refreshes_queue_before_next_action():
    start = SRC.index('} catch (error) {', SRC.index("rpc('gs_update_kitchen_status'"))
    block = SRC[start:SRC.index('} finally {', start)]
    assert '_refresh();' in block
    assert 'expectedQueueGeneration == _loadGeneration' in block

def test_handover_item_failure_is_bound_to_original_session_and_queue():
    start = SRC.index('handoverItems = await _loadItems(id)')
    block = SRC[start:SRC.index('final validItems', start)]
    assert 'employeeId == _loadedUserId' in block
    assert 'queueGeneration == _loadGeneration' in block

def test_authoritative_rpc_remains_the_only_status_write():
    assert "rpc('gs_update_kitchen_status'" in SRC
    assert ".update({'status':" not in SRC
