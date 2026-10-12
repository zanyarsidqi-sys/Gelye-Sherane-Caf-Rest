# Dashboard — refresh resilience and date safety

- Added last successful refresh timestamp and a non-sensitive refresh failure notice.
- Centralized refresh so manual refresh and date changes use the same loading behavior.
- Added safe date labels for chart rows to prevent substring crashes if the database returns an unexpected date representation.
- Updated migration guidance to include 034.

## Verification still required

Run `flutter analyze`, deploy migrations through 034, verify staff permissions, compare dashboard cash/order values to the payment ledger, and test responsive layouts. This package has not been compiled or live-tested.
