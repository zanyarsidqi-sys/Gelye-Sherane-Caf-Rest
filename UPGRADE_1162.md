# Upgrade 1162 — Kitchen foreground synchronization

The live Kitchen queue now refreshes whenever the Flutter application resumes
from the background. This invalidates stale item previews and confirmation
dialogs so employees do not act on a previously loaded queue after returning
to the app. The lifecycle observer is unregistered on disposal.

Verification: source regression tests only; Flutter and Supabase testing are
deferred until laptop access. This is not production sign-off.
