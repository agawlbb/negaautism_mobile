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
Browsing dropdowns show only categories and counties represented by approved
providers. Add/edit forms keep the complete category and county choices.
Website links open in the external browser, and phone links open the device's
phone app. Login is available from the header's three-dot menu only.

Accounts with the Firebase `manage_providers` claim can add and edit providers.
The app refreshes the token before saving; the server checks the claim and token
revocation independently. User type and notification preferences do not grant
management access. New providers added by verified managers are approved
immediately by the website API. Public submissions retain their approval
workflow. Editing preserves approval, submitter and reviews. The directory shows
provider logos; add/edit forms allow a JPG/PNG upload (up to 500 KB), with a preview.
Omitting an upload preserves the existing logo. Approval changes and deletion
remain website operations.

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

## Provider website assistance

New provider forms offer **Fill from website** through the dedicated
`wss://vps.negaautism.org/ws` service. Task branch `feature/ai-provider-import`
is based on fetched `origin/master` at `1c08e78`. The app sends a fresh Firebase
manager token, website URL and existing category/county choices. The VPS reads
relevant linked pages and returns suggestions; no hosted backend change is needed.

The AI review is a complete editable provider form: name, description, website,
phone, category and county are always available, even when extraction returns
no value. Existing values are retained unless selected or edited. An equivalent
HTTPS website suggestion (such as justpeople.org to https://justpeople.org) is
selected automatically; a different website or page is not.
The AI review screen validates required fields before **Add provider** saves
the reviewed form through the existing hosted API. The review keeps administrator
notes and supporting addresses without showing a Sources section or introductory
instructions. The entry form also omits instructional paragraphs.
Successful adds close both review and entry screens and return to the directory.
**Apply changes to provider form** transfers all reviewed edits back to the
entry form, including cleared optional fields. The manual form also returns
to the directory after a successful add.
Incomplete or failed adds stay open; database writes are never automatically
retried, and private review notes/sources are never submitted. Website
assistance applies to new entries, preserving the existing edit workflow.
Public descriptions follow the one-useful-paragraph, neutral third-person
standard with no AI-added warnings/cautions. Sources, uncertainty and supporting
addresses appear only in administrator review notes, and are never saved as part
of the public description. Unknown choices remain unselected.

The client reconnects using the same owner-bound request ID and refreshed token;
it never silently starts a replacement AI call. Results expire after 15 minutes
or a service restart. Manual entry remains available after errors. Native
Android WebSockets use `dart:io`, adding no package dependency. The VPS must have
its extraction implementation and credentials deployed before this action works.
No APK build, installation, or distribution is implied by source integration.

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

## Provider logos (development branch)

`feature/app-development` adds directory thumbnails and native JPG/PNG file
selection to provider entry and AI review. The official `file_selector` plugin
uses Android implementation 0.5.2+4 (API 21+), preserving this app's API 23
minimum; newer implementation versions require API 24. Only its dependency
family was added; Firebase and security floors were preserved. Invalid or missing
hosted logo images show a fallback icon.

`feature/backend-development` discovers image URLs/labels on provider pages and
asks the model to suggest an actual logo. A selected discovered image is fetched
with public-address/redirect checks and normalized to a bounded PNG preview.
AI previews can be discarded/replaced; a previously selected upload is retained
until the administrator chooses the website suggestion. If a source logo cannot
be prepared (for example SVG), review retains its source link and supports a
manual JPG/PNG upload. Text extraction still succeeds without a logo.

Uploads use an authenticated multipart request to the existing hosted provider
save API and are saved with the other provider fields. The website API extension
is prepared in `agawlbb/negaautism.org` branch `feature/mobile-provider-logos`;
that extension must be deployed before the mobile upload feature is used.
No merge, hosting/VPS deployment, APK build or installation accompanies this work.
