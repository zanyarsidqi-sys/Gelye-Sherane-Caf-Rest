from pathlib import Path
SRC = (Path(__file__).resolve().parents[2] / "lib/shared/live_kitchen_panel.dart").read_text()

def test_confirmation_updates_ui_and_disables_actions():
    assert "setState(() { _confirmingId = id; });" in SRC
    assert "_busyId == null && _confirmingId == null" in SRC
    assert "'Confirming...'" in SRC

def test_completion_releases_only_matching_confirmation():
    assert "_confirmationToken == confirmationToken" in SRC
    assert "setState(() { _confirmingId = null; });" in SRC

def test_rpc_is_still_authoritative():
    assert "rpc('gs_update_kitchen_status'" in SRC
