# Security validation - October 21, 2026

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
