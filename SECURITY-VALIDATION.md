## October 29, 2026 — first iOS TestFlight build

The user authorized GitHub Mac runners and TestFlight publication. Version
2.1.0/build 3 was built on the xcode-27 runner with Flutter 3.47.8/Dart 3.13.7.
Run 40959517253 passed analysis, the Flutter tests, six synthetic signing checks,
archive/export, strict exported signature and distribution-profile verification,
and App Store Connect upload. iOS 15 is the SDK minimum. CocoaPods is selected
for the existing pinned Firebase plugins after automatic SwiftPM migration failed;
Firebase package versions and Android configuration are preserved.

Private Firebase iOS configuration, the dedicated upload key and the explicitly
approved reused distribution certificate are encrypted GitHub Actions secrets.
They are reconstructed only on the ephemeral runner and cleaned after the job.
The manual workflow validates the signed app identity, team, build, profile,
production push entitlement and bundled Firebase identity before uploading.
Publishing source does not trigger a build or upload. No public App Store release
was submitted, and no real provider/notification operation was used as a test.

Apple completed processing with build state VALID and internal status
IN_BETA_TESTING. Version 2.1.0 (3) is assigned to the approved two-person Family
testers internal group. No external beta or public App Store submission was made.
Physical iPhone acceptance and Firebase APNs provider configuration remain pending;
source/signature checks do not prove push delivery or device behavior.

# Security validation

## October 29, 2026 - provider branch Android emulator build

The user explicitly authorized an Android build and emulator installation from
feature/provider-directory. Flutter 3.47.8 (official tag 737ba8f885) / Dart 3.13.7
was installed as isolated ignored build tooling; shared Flutter installations
were not modified. Exact dependency resolution with --enforce-lockfile passed.
The committed package lockfile and Firebase package versions remain unchanged.

The patched SDK rejected AGP 8.6.0. Both AGP declarations now use 8.11.1 and
Kotlin uses 2.2.20, compatible with AGP 8.11.1 and Gradle 8.14.6. The existing
patched Gradle wrapper and minimum Android API 23 remain unchanged. Generated
Android build reports and Kotlin caches are ignored.

assembleDebug -Ptarget-platform=android-x64 passed under JDK 17 (195 tasks).
Flutter's default selection of Android Studio JBR 25 failed; direct Gradle
invocation with JAVA_HOME selecting JDK 17 succeeded without changing global
Flutter configuration or bypassing dependency validation. Flutter's automatic
source migrations were reverted before the successful build.

The resulting debug APK was installed on CoffeyTable_Pixel_8_API_36
(emulator-5554). The launcher org.negaautism.mobileapp/.MainActivity opened,
and Browse providers displayed live provider entries and the search/filter UI.
No login, provider save, notification authorization, production deployment or
release distribution was performed. This establishes local debug/emulator
compatibility, not release-mode or physical-device validation. Existing
toolchain/NDK deprecation warnings remain for later maintenance.

## October 29, 2026 - provider feature validation (no Android build)

Resolved dependencies offline using Flutter 3.47.8 / Dart 3.13.7 in the VPS
development container. SDK-pinned framework/test dependencies now match that SDK;
Firebase, HTTP and shared-preferences versions and existing security floors were
preserved. Local analysis and unit tests cover the provider client and existing
preference compatibility. Website API tests use synthetic authentication and a
temporary SQLite adapter, with no production calls or data.

Provider writes require the `manage_providers` Firebase claim and fresh token
verification on the server. Tokens are sent only in HTTPS request bodies, not
persisted by the provider client or placed in URLs. Android builds/device tests
remain laptop work. No Android build, iOS work, installation, deployment,
notification or GitHub runner was performed. Historical validation limits below
remain applicable to installed binaries.

## October 24, 2026 - native HTTPS SDK requirement (no rebuild)

Official advisory:
https://github.com/dart-lang/sdk/security/advisories/GHSA-frr6-h895-5pxp

The advisory fixes native TLS certificate validation in Dart stable 3.13.7 /
Flutter stable 3.47.8. This app makes HTTPS requests through package:http 0.13.6,
whose native client uses dart:io. Android builds made with the previously
validated Flutter 3.24.5 / Dart 3.5.4 SDK fall within the affected range.
Installed app SDK versions have not been established.

pubspec.yaml now requires Dart >=3.13.7 <4.0.0 and Flutter >=3.47.8.
Use a patched stable Flutter release; do not use the historical SDK below for
future app builds. Firebase and all package versions remain unchanged.

Read-only local inspection found android/local.properties selecting the isolated
Flutter 3.24.5 runtime at
<local Flutter 3.24.5 SDK>.
The shared PATH SDK at
<shared local Flutter SDK> reports Flutter 3.47.6 /
Dart 3.13.5 in bin/cache/flutter.version.json. Both are below the patched floor.
Neither SDK was modified or invoked during this update.

Validation was limited to source/configuration review and Git whitespace/diff
checks. No dependency resolution, Flutter/Dart commands, tests, Gradle tasks,
compilation, app builds, installation, release or deployment were run.
pubspec.lock is deliberately preserved as the last resolved dependency set;
its historical SDK entries do not demonstrate patched-SDK validation.

Pre-push inspection on October 24 found only the GitHub origin push target,
no active local Git hooks, no repository Actions workflows, no repository
webhooks, and only the ChatGPT Codex Connector GitHub App. No automatic app
build integration was present in those inspected settings.

Before a later release, select an installed patched stable SDK, resolve and
review SDK-pinned lockfile changes while preserving the prior security floors,
then validate Flutter/Android compatibility and rebuild/distribute the app.
That work remains deferred under the user's no-rebuild instruction. Source
constraints alone do not repair the SDK or any installed binary.

## October 21, 2026 - historical toolchain validation

Gradle wrapper upgraded from 8.7 to 8.14.6, the patched 8.x line for
GHSA-xwqc-3h47-hg64, with its official distribution SHA-256 pinned.
Android Gradle Plugin 8.6.0 and Kotlin 1.8.22 remain unchanged.
AGP 8.6 requires Gradle 8.7+ and JDK 17:
https://developer.android.com/build/releases/agp-8-6-0-release-notes

shared_preferences_android is constrained to >=2.3.4 and resolves to 2.4.7,
fixing GHSA-3hpf-ff72-j67p. The normal Pub resolver regenerated the lockfile with
Flutter 3.24.5 / Dart 3.5.4; SDK-pinned framework/test dependencies match that
supported SDK rather than the newer SDK that had generated the previous lock.

Local machine checks: pub get passed, flutter analyze reported no issues, and both
saved-profile/notification preference compatibility tests passed. These use a
mock preference store and do not prove on-device Android storage behavior.
Gradle --version and help passed under JDK 17.0.20.1, including Android and
Flutter Gradle plugin configuration. No production service was contacted.

Use JDK 17 with this toolchain. Installed Android Studio JBR 25 is outside the
selected Gradle line's runtime compatibility; global settings were not changed.
The existing build uses deprecated APIs incompatible with Gradle 9.0, so the
patched 8.x release preserves compatibility.

Both Android debug build task graphs passed. Actual
:app:compileDebugJavaWithJavac then passed (101 tasks) after replacing duplicate
Flutter-derived minimum SDK declarations with explicit API 23, as required by
the existing Firebase Auth dependency. This avoids the older supported Flutter
SDK default of 21 conflicting with Firebase's manifest. The patched Android
preferences implementation compiled in that check. No APK was signed, installed
or deployed, and no signing credentials were created.

## October 29, 2026 - provider website assistance source validation

Flutter 3.47.8 / Dart 3.13.7 analysis and synthetic transport/review tests cover
same-ID reconnect without repeating AI work, fresh token callbacks, permission
failure before connection, explicit selection, preservation of populated fields,
and separation of private notes/sources from provider save fields. Existing
provider/contact/filter/preferences tests are retained. No new Flutter dependency
is introduced. The shared SDK, hosted backend, installed app and approval workflow
are unchanged. No Android/iOS build, app installation, release or provider save
was performed. The VPS service uses its own OpenAI key; no key is in mobile code.
Real authenticated administrator and device validation remain outstanding.

## October 29, 2026 - direct add from AI review

Synthetic widget tests verify that review Add provider submits only the selected
suggestions combined with existing form values, saves once, and closes both
routes to the directory. Manual add also closes the entry route after save.
Tests cover a disabled button during submission, timeout retention without an
automatic write retry, and missing category/county preventing submission while
allowing manual completion. Fresh Firebase permission verification is shared by
both save paths; review notes, source excerpts and supporting addresses are not
save fields. HTTP saves and Firebase users/tokens are synthetic. No real provider
write, hosted backend change, Android build, installation or deployment occurred.

## October 29, 2026 - provider logo source validation

Directory logos resolve only safe filenames within the existing HTTPS logos
folder. Selected images use native file selection, JPG/PNG signatures and a
500 KB client bound; the hosted API independently decodes and sanitizes uploads.
Authenticated multipart saves are tested with synthetic bytes/tokens, preserving
JSON saves without uploads and excluding private review fields. Optional malformed
AI previews leave extracted text available. Review tests preserve an existing
selection and explicitly switch to a suggested image. No credentials were placed
in image URLs. The picker needs device/build validation; no APK build, install,
real provider write or service deployment was performed.

The Android file-selector implementation is pinned to 0.5.2+4 after inspecting
its official package source (minSdk 21). Newer 0.5.2+5 and later require minSdk
24. This preserves the existing app minSdk 23 without changing Flutter/Dart,
Firebase versions or the existing Android security floors.

## Direct VPS admin API revision (source only)

The mobile client uses fresh Firebase ID tokens in Authorization headers, rejects
account changes during a request and never automatically retries mutations.
The VPS validates current permissions/account status and performs business
operations directly. Privileged Firebase credentials are provisioned privately
on the VPS, not shipped in the client. No website PHP API is called. InMotion
supplies only database and logo storage; its file API receives only the server's
storage credential and safe fixed-folder image operations, never user tokens.
The existing explicitly approved non-TLS MySQL transport remains unchanged.

Provider metadata/review/approval preservation, shared-logo safety and SQL/Firebase
failure cases are covered with synthetic mutations. The same PDF layout, fonts,
branding and QR implementation now execute locally on the VPS. Its PHP child gets
only public provider fields and no secret environment. Renderer and booklet tests
cover complete pages, Unicode, unsupported text, unsafe logos and overflow.

The unchanged mobile API/native UI passed 54 tests and Flutter analysis in the
preceding source checkpoint. This backend revision introduces no mobile dependency
or SDK change. Native Kotlin/Swift compilation and document-picker device tests
remain outstanding. No app build, installation, production content/user mutation,
notification, deployment or forum work accompanies this revision.
