# Upgrade 222 — Universal Printer Registry & Queue Foundation

Added `gs_cafe_printers` and `gs_cafe_print_jobs` tables, secured with RLS and no direct client table privileges. Added permission-gated listing RPCs and manager-only printer registration RPC. Added a read-only Printer Center in Section 02 — Tables showing configured devices and recent jobs, with stale connectivity marked unknown.

Connection types: Wi-Fi, LAN, Bluetooth, USB, Cloud. Bluetooth/USB need an always-on local gateway for remote use. **No actual print transport, gateway heartbeat, print submission, printer discovery, status confirmation, or driver integration is implemented yet.** Status and queued-job counts will remain empty until integrated. A printed status should not be considered physical-paper confirmation unless supported by hardware.

No Flutter compile or live Supabase migration was performed. ZIP integrity/uniqueness checked. Section 02 remains at 94% estimated because printer work is new unfinished scope. Customers paused at 45%.
