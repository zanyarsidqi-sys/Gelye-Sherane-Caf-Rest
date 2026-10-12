# Upgrades 585–604 — Sections 01–07 integration reliability

- 585: Kitchen rejects actions from unauthenticated employee sessions.
- 586: Kitchen binds loaded queue to employee identity.
- 587: Kitchen checks employee identity after each paginated fetch.
- 588: Kitchen discards stale results after filter changes.
- 589: Kitchen refresh invalidates in-flight result generation.
- 590: Kitchen prevents overlapping status-update requests.
- 591: Kitchen refuses edits when employee identity differs from queue owner.
- 592: Kitchen avoids refreshing another employee’s queue after a write.
- 593: Kitchen avoids exposing a failed write under a different employee session.
- 594: Kitchen requires mounted widget after handover confirmation.
- 595: Kitchen guards against missing or invalid order IDs.
- 596: Kitchen applies deterministic ID tie-breaking to chronological sort.
- 597: Kitchen protects order-item fetches with authentication check.
- 598: Live records paginate instead of silently limiting to 100.
- 599: Live records filter table/motel records on the server before pagination.
- 600: Live records use stable ID ordering for pagination.
- 601: Live records discard in-flight results after employee changes.
- 602: Live records warn when the 5,000-record safety cap is reached.
- 603: Live records show accurate no-match guidance for capped datasets.
- 604: Live records refresh invalidates stale fetch generations.

## Scope and limitations
These are 20 incremental source-level improvements consolidated into one complete project. They do not imply that Sections 01–07 are 100% ready. Flutter compilation, live Supabase integration, end-to-end testing and UI reviews are still pending. No schema migration was required for these changes.
