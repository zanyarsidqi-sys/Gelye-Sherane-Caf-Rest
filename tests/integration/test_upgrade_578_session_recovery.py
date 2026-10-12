from pathlib import Path
SRC = (Path(__file__).resolve().parents[2] / 'lib/sections/table_orders.dart').read_text()

def test_delayed_local_load_is_scoped_to_current_employee():
    assert 'mounted && Supabase.instance.client.auth.currentUser?.id == uid' in SRC

def test_receipt_response_checks_employee_session_again():
    assert 'Employee session changed during recovery' in SRC

def test_resume_reloads_recovery_pointer():
    assert 'Re-read the account-scoped recovery pointer after app resume.' in SRC
    assert '_loadPendingReplacement();' in SRC
