from pathlib import Path

SOURCE = (Path(__file__).resolve().parents[2] / 'lib/shared/live_kitchen_panel.dart').read_text()

def test_success_refresh_after_concurrent_manual_refresh():
    block = SOURCE.split("rpc('gs_update_kitchen_status'", 1)[1].split('} catch (error)', 1)[0]
    assert '_busyOperationToken == operationToken) _refresh();' in block
    assert 'expectedQueueGeneration == _loadGeneration) _refresh();' not in block

def test_error_refresh_after_concurrent_manual_refresh():
    block = SOURCE.split("rpc('gs_update_kitchen_status'", 1)[1].split('} catch (error)', 1)[1].split('} finally', 1)[0]
    assert '_busyOperationToken == operationToken' in block
    assert '_refresh();' in block

def test_cross_account_operation_token_protection_remains():
    assert '_busyOperationToken++;' in SOURCE
    assert '_isCurrentEmployee(employeeId)' in SOURCE
