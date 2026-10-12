from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
SRC=(ROOT/'lib/sections/kitchen.dart').read_text()

def test_mobile_tab_bar_scrolls_instead_of_compressing_labels():
    assert 'TabBar(isScrollable: true, tabAlignment: TabAlignment.start' in SRC

def test_all_three_operational_queues_remain():
    for panel in ('LiveKitchenPanel()', 'KitchenScheduledMotelMealsPanel()', 'KitchenMotelFoodQueuePanel()'):
        assert panel in SRC
    assert 'length: 3' in SRC
