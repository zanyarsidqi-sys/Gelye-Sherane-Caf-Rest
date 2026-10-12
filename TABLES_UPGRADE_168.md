# Tables Upgrade 168 — Independent finance review Flutter action

The Tables bill-transfer request detail dialog now offers **Record independent finance review**. A confirmation dialog explains that this is an immutable, review-only action. On confirmation, the Flutter client calls `gs_record_table_transfer_finance_review(p_request_id)` from Upgrade 167, and displays the review ID or permission/MFA error.

The backend requires finance edit permission, table-order view permission, MFA (`aal2`), and a reviewer different from the requester. The review does **not** approve a request, allocate payment, or execute a transfer.

Tables development: **59% estimated**, 7/20 major milestones completed, 13 remaining. ZIP checked; Flutter compilation and live Supabase testing pending.
