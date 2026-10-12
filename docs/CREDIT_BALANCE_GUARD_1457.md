# Upgrade 1457 — credit charge balance guard

A new BEFORE INSERT trigger rejects journal charges unless the account row already reflects the exact `outstanding_after_iqd` value. Existing atomic posting updates the account before inserting the journal. The request uniqueness index and other credit invoice triggers remain active.

This is an additional guard, not an invoice settlement or prepaid allocation. **Not deployed or live tested.** Before deployment, run on a staging clone: migration replay, a valid atomic posting, a direct privileged insert without account update (must fail), a duplicate request (must fail), concurrent account charges, retries and transaction rollback. Historical charges are not modified.
