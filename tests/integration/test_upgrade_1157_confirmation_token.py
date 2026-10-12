from pathlib import Path
SRC=(Path(__file__).resolve().parents[2]/'lib/shared/live_kitchen_panel.dart').read_text()

def test_each_confirmation_has_unique_token():
    assert 'final confirmationToken = ++_confirmationToken;' in SRC
    assert '_confirmationToken == confirmationToken' in SRC

def test_auth_change_invalidates_old_dialog():
    section=SRC[SRC.index('onAuthStateChange.listen'):SRC.index('String _query')]
    assert '_confirmationToken++;' in section

def test_dispose_invalidates_old_dialog():
    section=SRC[SRC.index('void dispose()'):SRC.index('// Money is stored')]
    assert '_confirmationToken++;' in section
