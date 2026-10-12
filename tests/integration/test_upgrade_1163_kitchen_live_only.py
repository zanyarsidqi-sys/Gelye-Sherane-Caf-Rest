from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SRC=(ROOT/'lib/sections/kitchen.dart').read_text()
def test_kitchen_live_queue():
    assert "import '../shared/live_kitchen_panel.dart';" in SRC
    assert 'LiveKitchenPanel()' in SRC
    assert "OrderPreviewWorkspace(kind: 'kitchen')" not in SRC
def test_other_tabs_unchanged():
    assert 'KitchenScheduledMotelMealsPanel()' in SRC
    assert 'KitchenMotelFoodQueuePanel()' in SRC
    assert 'length: 3' in SRC
def test_backend_authorization_retained():
    live=(ROOT/'lib/shared/live_kitchen_panel.dart').read_text()
    assert "rpc('gs_update_kitchen_status'" in live
