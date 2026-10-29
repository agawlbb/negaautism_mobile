# negaautism_mobile

Mobile app for negaautism

## SDK requirement

Use Flutter stable 3.47.8 or later with Dart 3.13.7 or later, as required by
[GHSA-frr6-h895-5pxp](https://github.com/dart-lang/sdk/security/advisories/GHSA-frr6-h895-5pxp).
The SDK minimums in `pubspec.yaml` reject the older SDK used for previous validation.

The October 24, 2026 update changes source configuration only. Shared SDKs and
installed apps have not been updated. Dependency resolution, compatibility
validation, rebuilding and distribution are deferred under the user's no-rebuild
instruction. The existing lockfile still records the previous Flutter dependency
set; resolve it using the patched stable SDK when that work is authorized.
See [security validation](SECURITY-VALIDATION.md) for the exact validation limits.

## Provider directory

The home screen uses the website's teal/cream palette and rainbow branding,
with its `img/child_reading.webp` illustration bundled locally as
`assets/images/child_reading.webp`. The image is available offline and stays on
the home screen when the provider directory opens.

`Browse providers` is available without signing in. Search by name or description,
filter by county/category, and expand a provider to view their description,
phone and website. County filtering includes providers serving multiple counties.
Website links open in the external browser, and phone links open the device's
phone app. Login is available from the header's three-dot menu only.

Accounts with the Firebase `manage_providers` claim can add and edit providers.
The app refreshes the token before saving; the server checks the claim and token
revocation independently. User type and notification preferences do not grant
management access. New providers await approval in the existing website admin
workflow. Editing preserves approval, logos, submitter and reviews. Logo uploads,
approval and deletion remain website operations.

This feature requires the website's `api/get_providers.php` and
`api/save_provider.php`, documented in its `docs/mobile-provider-api.md`. Website
deployment is separate; an unavailable API displays an error with a retry option.

Development and tests run in the VPS development container; Android builds and
device validation run on the laptop. Do not use GitHub Actions runners. There is
no iOS app in the current scope. No production writes are needed for tests:

```
flutter pub get --offline
flutter analyze --no-pub
flutter test --no-pub --concurrency=1
```

The October 29 provider work resolved the lockfile with Flutter 3.47.8 / Dart
3.13.7 for local analysis/tests. This updates SDK-pinned framework/test packages;
it does not establish Android build compatibility or update installed apps.

## Getting Started

### Android emulator build (October 29, 2026)

The provider-directory branch builds with Flutter 3.47.8 / Dart 3.13.7,
JDK 17, AGP 8.11.1, Kotlin 2.2.20 and the existing Gradle 8.14.6 wrapper.
Use JDK 17 explicitly when invoking Gradle; Android Studio's installed JBR 25
is incompatible with this wrapper. After resolving the committed lockfile with
the patched Flutter SDK and setting its path in ignored `android/local.properties`:

```powershell
$env:JAVA_HOME = '<JDK 17 installation>'
.\android\gradlew.bat -p android assembleDebug -Ptarget-platform=android-x64
```

The debug APK is `build/app/outputs/apk/debug/app-debug.apk`. This is an emulator
development build, not a production release. Shared SDKs, Firebase package
versions and production services are unchanged. The earlier no-build record
above is historical; this local debug build was explicitly authorized.

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
