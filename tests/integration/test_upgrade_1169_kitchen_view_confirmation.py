from pathlib import Path
S = (Path(__file__).resolve().parents[2] / 'lib/shared/live_kitchen_panel.dart').read_text()

def test_search_invalidates_confirmation():
    part = S[S.index('final nextQuery = value.trim().toLowerCase();'):S.index('const SizedBox(height: 8)')]
    assert '_confirmationToken++;' in part and '_confirmingId = null;' in part

def test_sort_invalidates_confirmation():
    part = S[S.index('onChanged: (value) => setState(() {\n        _oldestFirst'):][:230]
    assert '_confirmationToken++;' in part and '_confirmingId = null;' in part
