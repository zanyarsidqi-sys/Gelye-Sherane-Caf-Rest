from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[2]
def test_notification_auth_subscription():
 s=(ROOT/'lib/sections/notifications.dart').read_text()
 assert 'onAuthStateChange.listen' in s and '_authSubscription?.cancel()' in s
 assert 'request == _permissionRequest' in s and 'currentUser?.id == userId' in s
def test_offline_session_isolation():
 s=(ROOT/'lib/sections/offline_mode_synchronization.dart').read_text()
 assert 'onAuthStateChange.listen' in s and '_authSubscription?.cancel()' in s
 assert 'request != _cursorRequest' in s and 'request == _cursorRequest' in s
 assert 'fetched?.userId == currentUserId' in s
 assert "_cursorError = 'Unable to fetch notifications." in s
def test_all_35_section_source_checks():
 data=json.loads((ROOT/'ALL_35_SECTIONS_PROGRESS_1133.json').read_text())
 assert len(data['sections'])==35
 assert all(r['registered'] and r['permission_wrapper'] and r['section_id_matches'] for r in data['sections'])
 assert len(set(r['section'] for r in data['sections']))==35
