# Upgrade 1192 — Station device user authorization

Adds supervisor-controlled user-to-device authorization and a permission-scoped
list of the current employee's authorized devices. An employee must be assigned
to the station and the device must be enabled. Revoke using the Station Devices UI.

**Security boundary:** This is a database authorization *registry*, not hardware
attestation. A copied UUID or device label is not a credential. Existing station
RPCs still authenticate the employee and check station assignment; they do not
require a device session. Device enrollment, attestation, and binding requests to
a trusted device identity remain separate work. Do not treat this as complete
hardware-enforced station isolation.

Live Supabase migration and Flutter compilation were not run per user request.
