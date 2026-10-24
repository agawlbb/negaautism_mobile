# Security validation

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
