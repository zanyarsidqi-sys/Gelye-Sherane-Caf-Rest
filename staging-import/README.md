# Release 1.0.0.2 recovery source upload

Upload ONLY `release-1.0.0.2-source.zip` to this directory on branch `staging/release-1.0.0.2-recovery`.

Expected SHA-256: `fc4e6875f7a98ab6c8d91f913aeb60a470ca842687d197b2992097248638f99b`.

The recovery import workflow must verify the checksum, ZIP integrity, 35 management section Dart files, and protected paths before committing source. Do not merge into main or deploy production.
