# Upgrade 1163 — Kitchen live-only order queue

Kitchen Orders now directly renders `LiveKitchenPanel`, removing the local demonstration toggle and locally simulated kitchen orders from the operational screen. Table and Motel order preview tools remain unchanged. All three Kitchen tabs are preserved.

Three source tests pass. Flutter and live Supabase tests remain deferred.
