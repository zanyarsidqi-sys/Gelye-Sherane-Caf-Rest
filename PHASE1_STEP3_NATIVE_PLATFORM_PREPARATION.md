# Phase 1 — Step 3: Native platform preparation

Application title: Gelye Sherane Cafê & Rest
Flutter package: gelye_cafe_rest
Proposed Android application ID: com.gelyesherane.caferest
Proposed iOS bundle ID: com.gelyesherane.caferest
Proposed Windows executable: gelye_cafe_rest

These IDs are proposals, not registered or verified store identifiers.

## Required on a development machine with Flutter SDK
1. Back up the project and open the project root.
2. Run `flutter doctor -v` and install missing platform prerequisites.
3. Run `flutter create --platforms=android,ios,windows --project-name=gelye_cafe_rest --org=com.gelyesherane .`.
4. Inspect the generated Android application ID and iOS bundle identifier. Change them to the proposed distinct IDs above if necessary; verify all build flavors and signing settings.
5. Set the native display name to `Gelye Sherane Cafê & Rest` for Android and iOS, and Windows runner window title as appropriate.
6. Run `flutter pub get`, `flutter analyze`, `flutter test`, and platform builds on supported host operating systems.
7. Configure distinct Supabase credentials through the supported environment mechanism. Never commit service-role keys or production secrets.

## Verification
- Native folders are NOT included in this ZIP; Flutter SDK is unavailable in this execution environment.
- Android/iOS/Windows builds have NOT been performed.
- Web Apple application-title metadata has been corrected.
- Existing source code has been preserved.
