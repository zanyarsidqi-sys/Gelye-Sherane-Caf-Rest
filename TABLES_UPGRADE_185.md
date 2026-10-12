# Upgrade 185 — Create Table and Choose Chairs

Added a **Create Table** action to Section 02 — Tables. Authorized employees
enter a unique positive table number and a starting capacity of 1–50 chairs.
The Supabase RPC checks permissions, creates the table as unoccupied with
zero guests in Normal Mode, and records the creator and starting capacity.
Database uniqueness prevents duplicate table numbers. After success, the
Flutter table list refreshes. Existing chair adjustments remain available.

**Not live-tested:** Flutter compilation, migrations, and Supabase permissions
must be verified before production use. The SQL audit table is inaccessible
to normal app roles but no special immutable trigger has been added for
privileged database users. Takeaway & Delivery remain table-free.

Tables estimated 61% complete; original milestone tracking unchanged.
