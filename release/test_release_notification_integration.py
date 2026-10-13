from pathlib import Path
root=Path(__file__).resolve().parents[1]
sql=(root/'supabase/migrations/20261012_1494_release_notification_readiness.sql').read_text()
ui=(root/'lib/shared/notification_center_panel.dart').read_text()
push=(root/'supabase/setup/browser_push.sql').read_text()
edge=(root/'supabase/functions/browser-push/index.ts').read_text()
payload=(root/'supabase/functions/browser-push/contracts.mjs').read_text()
notice=(root/'lib/shared/release_update_notice.dart').read_text()
update_button=(root/'lib/shared/app_update_button.dart').read_text()
update_script=(root/'web/app_update.js').read_text()
assert "new.action='publish'" in sql and "deployment_verified" in sql
assert 'before insert on public.gs_app_release_events' in sql
assert "e.action='publish'" in sql and "r.platform='web'" in sql
assert 'gs_my_published_release_history' in ui and '_releaseHistoryCard()' in ui
assert "gs_app_available_update" in ui and "_availableUpdateCard()" in ui
assert "AppUpdateButton" in ui and "if (kIsWeb)" in notice
assert "Save your work before continuing." in update_button
assert "registration.update()" in update_script and "window.location.reload()" in update_script
assert "new.action <> 'publish'" in push
assert 'on conflict do nothing' in push
assert "job.source_table==='gs_app_release_events'" in edge
print('Release notification integration source contract: PASS')

# Release notifications use Notifications permission, not just dashboard access.
assert "select s.id,'gs_app_release_events',new.id,'notifications'" in push
assert "p_section:job.section_key" in edge
assert "select=version,notes" in edge
assert "publicPayload(tag,version,notes)" in edge
assert "releaseNotesPreview(notes)" in payload
assert "deliveryDecision({eligible,subscriptionPresent:rows.length>0,releaseEvent:true,publishedRelease:releases.length>0})==='failed'" in edge
print('Release notification permission and dispatch eligibility: PASS')
