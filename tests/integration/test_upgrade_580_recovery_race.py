from pathlib import Path

SOURCE = Path(__file__).resolve().parents[2] / 'lib/sections/table_orders.dart'
text = SOURCE.read_text()


def test_pending_recovery_checks_identity_after_async_clear():
    assert "await TableReplacementRecovery.clear(uid, pending['request_id'] as String);\n        // Local persistence is asynchronous." in text
    assert "if (!mounted || Supabase.instance.client.auth.currentUser?.id != uid) return;" in text
    assert "if (_pendingReplacement?['request_id'] != pending['request_id']) return;" in text


def test_recovered_commit_checks_session_after_clear():
    assert "await TableReplacementRecovery.clear(actorId, requestId);\n            if (!mounted || client.auth.currentUser?.id != actorId) return;" in text


def test_direct_commit_checks_session_after_clear_and_refreshes():
    assert "await TableReplacementRecovery.clear(actorId, requestId);\n      if (!mounted || client.auth.currentUser?.id != actorId) return;" in text
    assert "await refresh();" in text
