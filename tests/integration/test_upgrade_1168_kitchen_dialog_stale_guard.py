from pathlib import Path
SRC=(Path(__file__).resolve().parents[2]/'lib/shared/live_kitchen_panel.dart').read_text()

def test_stale_item_fetch_cannot_open_confirmation_dialog():
    begin=SRC.index('handoverItems = await _loadItems(')
    end=SRC.index('final confirmed = await showDialog<bool>',begin)
    block=SRC[begin:end]
    assert 'confirmationToken != _confirmationToken' in block
    assert '_confirmingId != id' in block
    assert 'queueGeneration != _loadGeneration' in block

def test_confirmation_is_revalidated_before_rpc():
    begin=SRC.index('final confirmed = await showDialog<bool>')
    end=SRC.index('await _advance(id, next',begin)
    assert 'confirmationToken != _confirmationToken' in SRC[begin:end]
