from pathlib import Path

SRC = (Path(__file__).resolve().parents[2] / "lib/shared/live_kitchen_panel.dart").read_text()

def test_filter_switch_invalidates_open_confirmation():
    block = SRC[SRC.index("onSelected: (_) {"):SRC.index("const SizedBox(width: 6)", SRC.index("onSelected: (_) {"))]
    assert "_confirmationToken++;" in block
    assert "_confirmingId = null;" in block
    assert "_loadGeneration++;" in block
    assert block.index("_confirmationToken++;") < block.index("_orders = _load();")

def test_confirmation_token_checked_before_rpc():
    assert "confirmationToken != _confirmationToken" in SRC
    assert "await _advance(id, next" in SRC

def test_live_kitchen_screen_still_preserves_three_tabs():
    screen = (Path(__file__).resolve().parents[2] / "lib/sections/kitchen.dart").read_text()
    for name in ("LiveKitchenPanel()", "KitchenScheduledMotelMealsPanel()", "KitchenMotelFoodQueuePanel()"):
        assert name in screen
