# Privacy and footer correction — pending build/deployment

Removed the manual section conceal/reveal action. Automatic permission rechecks now reveal content after successful access validation, retaining generation and future identity checks. Background concealment and denied-access behavior remain.

Dashboard footer now uses AppReleaseVersion.label, as CafeApp already does. Release label remains 1.0.0.1; no new deployment is claimed. pubspec package version 1.0.0+29 remains separate from the public release label.

At the initial inspection, browser push was not implemented. The subsequent staged implementation and current activation requirements are documented in DEVICE_SESSION_AND_WEB_PUSH_SETUP.md. NotificationCenterPanel describes local-device-only state. No push subscription, VAPID sender or web push handler was found. Adding to the iPhone Home Screen and granting permission is necessary but cannot supply missing server/client push functionality.

Validation: inspected edited source and archive preservation. Flutter SDK unavailable; no compilation, runtime, live deployment, or push delivery test performed. Older source-string tests expecting the removed privacy prompt are now obsolete and have not been presented as passing.
