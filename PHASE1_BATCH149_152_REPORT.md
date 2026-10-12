# Phase 1 Steps 149–152

- Serialize physical printer writes shared by original and revision queues
- Prevent concurrent lifecycle starts and stale asynchronous start after stop
- Clean up partial worker initialization on start errors
- Add two Dart regression tests for serialized printing and recovery

Dart tests not run: SDK unavailable.
