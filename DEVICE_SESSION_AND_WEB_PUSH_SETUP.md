# Saved device sessions and browser push — staged implementation

## Implemented source changes
- First-login duration: running app only (default), 1/8/24 hours, 7/30 days, custom 1–8760 hours, until logout.
- Stores only a local preference and session identity, not passwords or extra copies of tokens. Supabase continues managing the original session.
- A remembered device still needs a valid server session, AAL2 MFA, active employee profile and current section permissions. The chosen deadline never extends a server session. It is a device convenience deadline, not a new server-enforced JWT lifetime. Device clock or local-storage tampering is outside this local preference's guarantee.
- Duration is fixed from login, never extended by browsing sections. Login/account changes cannot inherit the previous login's preference. Existing sessions without a preference need one fresh login.
- Logout and local expiry stop this device's browser subscription and sign out the local Supabase session. Other devices are not intentionally signed out.
- Browser notification controls: Home Screen instructions, enable, test, disable. Installation and permission require the employee's own taps.
- Worker uses its own /push/ scope to avoid replacing Flutter's worker. Alerts show generic work text, or the published release version; no customer/payment/report content.
- Durable per-device queue for existing service-task and kitchen station notifications, plus published stable web release events. Only configured subscribed browsers receive pushes.
- Release draft/ready transitions never enqueue pushes. A stable web publish event queues one job per subscription; unique constraints prevent duplicate queue entries. Delivery rechecks current publication and permissions. Provider retries are at-least-once, not guaranteed exactly-once; repeated jobs use a stable notification tag.
- This does not add push triggers to every other business event. Native iOS/Android notification delivery remains separate.

## Activation still required
1. Validate `supabase/setup/browser_push.sql` against a staging database containing the existing employee, service-task, station and release schemas. Supabase CLI was unavailable, so this is a staged setup script, not an invented migration filename. After validation, create an official migration using `supabase migration new browser_push` and place the reviewed SQL in it.
2. Review database advisors and verify authenticated/anonymous callers cannot read subscription endpoints or dispatch jobs; verify inactive employees, removed permissions, signed-out sessions and expired subscriptions cannot receive new alerts.
3. Generate one VAPID key pair with web-push 3.6.7. Put `WEB_PUSH_PRIVATE_KEY`, `WEB_PUSH_PUBLIC_KEY`, `WEB_PUSH_SUBJECT` (a real contact mailto: address), `WEB_PUSH_ALLOWED_ORIGINS` (exact HTTPS origins, comma-separated) and a random >=32-character `WEB_PUSH_DISPATCH_SECRET` in Edge Function secrets. Never put private keys or dispatch secrets in Flutter or git.
4. Deploy `supabase/functions/browser-push`. Because dispatch uses its own secret, configure this function with platform JWT verification disabled; its code independently verifies employee JWTs through Auth for subscribe/test operations and checks a constant-time secret for dispatch. Do not deploy if these application checks are removed. Pin npm:web-push@3.6.7 and generate/review the Deno dependency lock during deployment.
5. Configure a trusted scheduled job (for example Supabase Cron with Vault-managed secret) every minute to POST {"action":"dispatch"} with Authorization: Bearer <dispatch secret>. Never expose the scheduler secret in public SQL examples, app source or browser scripts. Monitor failed jobs. Queue retries cap at 5 and delivery is not guaranteed when devices or providers are unavailable.
6. Rebuild Flutter with `--dart-define=WEB_PUSH_PUBLIC_KEY=<public key>` alongside its existing Supabase settings. Include push_client.js and push/sw.js in hosting output with correct JavaScript MIME types. Preserve existing business data and deployment configuration.
7. Publish the rebuilt site and verify the footer/build. Only after deployment and smoke tests succeed, mark the reviewed release published through the existing release workflow. The database publish status is the announcement signal; this code cannot independently attest a Cloudflare/GitHub deployment.
8. On an iPhone, add the site to Home Screen, open its icon, log in, go to Notifications and tap Enable notifications → Allow. Tap Send test and verify actual receipt, including while backgrounded. Test a later published version and verify drafts produce no push. Do not reuse a published version number for a new release.

## Verification completed here
- 10 Node tests passed: subscription endpoint restrictions, key validation, expiry range, safe release payload, iPhone installation gate, permission gesture order, failed-server unsubscribe cleanup, denied permission, safe notification-click destination.
- Node syntax checks passed for browser JavaScript, worker, and Edge Function TypeScript.
- Six Dart session-policy tests added but NOT run: Flutter/Dart SDK unavailable.
- No Flutter build, Deno dependency/type check, SQL execution, backend deployment, live device push, or live release announcement performed. No live customer data changed.
- Original project files retained, including the prior privacy-screen and footer changes. Public release label remains 1.0.0.1 until a newly approved build version is selected for publishing.

## Sources
- Apple: https://developer.apple.com/documentation/usernotifications/sending-web-push-notifications-in-web-apps-and-browsers
- Supabase sessions: https://supabase.com/docs/guides/auth/sessions
- Supabase sign-out: https://supabase.com/docs/guides/auth/signout
- Web Push implementation: https://github.com/web-push-libs/web-push
- Browser subscription API: https://developer.mozilla.org/en-US/docs/Web/API/PushManager/subscribe
