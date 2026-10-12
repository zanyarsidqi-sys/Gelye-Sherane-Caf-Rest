# Upgrade 1305 — Dashboard chart width constraints

Section 01 only. Wrap both seven-day chart labels (order count and date) in a full-width SizedBox before FittedBox(scaleDown). A FittedBox without a bounded width can retain intrinsic text width in narrow iPhone columns, so long values can overflow despite scaleDown. The new width constraint makes fitting relative to each Expanded chart cell. Existing semantics labels, RPC validation, permissions, and other sections unchanged.

Verification: ZIP CRC/integrity, archive entry retention, static source assertions, byte-for-byte preservation of untouched files. Flutter/Dart SDK unavailable; compile/device tests pending.
