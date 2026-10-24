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

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
