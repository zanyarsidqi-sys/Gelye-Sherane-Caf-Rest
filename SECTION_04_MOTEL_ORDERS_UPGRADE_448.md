# Upgrade 448 — Customer Identity Safety Hold

Authenticated customers can file a durable identity safety hold against an onboarding request, including **after** a previous acknowledgement. The request must belong to their authenticated user ID. Customer-facing APIs can list their own holds, but cannot delete them. Staff can inspect hold status with Credit Management view permission. An insert/update trigger blocks external evidence reviews on held requests, even when the Flutter UI is bypassed. Staff UI adds a Customer Safety Hold button.

**Important limitations:** The hold is not yet enforced across *every* identity review or onboarding pathway. Customer identity verification and consent are not enabled; credit debits remain blocked. Database migration and Flutter compilation have not been executed in a live environment.
