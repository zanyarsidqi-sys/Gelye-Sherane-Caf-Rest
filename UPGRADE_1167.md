# Upgrade 1167 — Kitchen in-flight RPC refresh consistency

Fixes a race: if an employee refreshes the Kitchen queue while an order status RPC is in flight, the earlier code suppressed the post-RPC reload because the queue generation had changed. The refreshed queue could therefore show the old status after a successful server transition.

Now the completed RPC refreshes the current queue on both success and rejection, as long as it still belongs to the same signed-in employee and the same operation token. Switching employee accounts invalidates the token and prevents cross-account updates.

Source regression tests are included. Flutter build and Supabase runtime testing remain deferred.
