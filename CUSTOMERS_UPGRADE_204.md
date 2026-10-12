# Upgrade 204 — Customer directory and visit history

- Replaced Customers section placeholder with customer directory, search, add profile, manual visit recording, visit history and ranking by number of recorded visits.
- New private customer and visit tables; no direct authenticated table access. Authenticated RPCs enforce `customers` or `tables` permissions; customer creation/visit recording require `can_edit`.
- Guest name is stored in the customer profile. Optional phone and notes are private and not exposed publicly.
- The ranking is **recorded visits only**; it does not claim to rank spending or automatically attach existing reservations/orders.
- Future work: customer selection at table check-in and reservations, automatic deduplicated visit linkage, verified payment linkage, and ranking by actual settled spend.
- Not live tested. Migration order after 203. Flutter compilation not run.
- Section 02 Tables: 82% estimated (unchanged until check-in integration); Section 08 Customers: initial functional foundation, 15% estimated.
