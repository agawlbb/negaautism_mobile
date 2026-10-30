# iOS and TestFlight

## App icon correction

Task `fix/ios-app-icon`, based on fetched `origin/master` at `65f0838`.
The iOS AppIcon catalog still held Flutter's template artwork while Android used
the supplied NEGA logo. All 15 PNG files now use the existing project artwork
from `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png`, flattened onto
white for opaque RGB iOS assets. The existing catalog and Xcode AppIcon settings
are unchanged. Every declared pixel size and absence of alpha were verified;
the 180-pixel iPhone icon was visually inspected. The available project launcher
source is 192 pixels, so the 1024-pixel marketing image is upscaled from that
source. No artwork was redesigned and no dependency was added.

This is an asset-only source correction. No macOS build, TestFlight upload or
installed-app change was performed. The corrected icon requires a subsequent
build and release by the release task.

## Startup correction — October 30, 2026

Task `codex/ios-startup-scene-fix`, based on fetched master `1698c88`.
TestFlight build 4 was reported to close on launch. Its customized AppDelegate
prevented Flutter's automatic UIScene migration, leaving the Xcode 27 build with
the unsupported legacy application lifecycle. Adopt FlutterSceneDelegate through
the scene manifest and register plugins and the PDF channel only after the
implicit engine initializes. PDF presentation uses the active scene's key window.

The iOS workflow now installs and launches the actual Firebase-configured app on
an iPhone simulator and checks that its process survives startup before upload.
It retains a launch screenshot when the runner has a simulator display; headless
runners still require app process survival and report visual validation as pending.
IPA validation also checks
the exported scene configuration. Simulator validation does not replace physical
iPhone acceptance, notification delivery or document-picker testing.

Validation run 41131274493 on fix commit 412dd19 passed the six signing tests,
Flutter analysis, all Flutter tests, simulator compilation, app process survival
for 20 seconds after launch, and unsigned release compilation. The headless
runner could not capture a display screenshot; visual and physical-device
acceptance remain pending. No replacement was uploaded by this validation run.
Apple had no submitted crash feedback available, so the scene incompatibility is
the identified startup defect rather than a symbolicated device-crash diagnosis.

Task: feature/ios-testflight-20261029. Base: b6194addb15510c5e1e39e4e8f1c6a6b9bc4ccc6.
Use the existing Flutter app and GitHub macOS runners for iOS and TestFlight.
The workflow runs only on workflow_dispatch; pushing does not publish a build.

## Account setup

1. Join the Apple Developer Program and create an explicit App ID with Push
   Notifications. Register that same bundle ID as an iOS app in the existing
   Firebase project, and download its GoogleService-Info.plist.
2. Create the app record in App Store Connect with that bundle ID.
3. Export an Apple Distribution certificate with its private key as a password
   protected P12. Create an App Store distribution provisioning profile for the
   same App ID. Supply an App Store Connect API key with upload access.
4. Add these repository Actions secrets through GitHub Settings (never source):

| Secret | Value |
| --- | --- |
| FIREBASE_IOS_PLIST_BASE64 | Base64 of the iOS Firebase plist |
| IOS_DISTRIBUTION_P12_BASE64 | Base64 of the certificate and private key P12 |
| IOS_DISTRIBUTION_P12_PASSWORD | P12 export password |
| IOS_PROFILE_BASE64 | Base64 of the App Store provisioning profile |
| ASC_KEY_ID | App Store Connect API key ID |
| ASC_ISSUER_ID | App Store Connect issuer ID |
| ASC_PRIVATE_KEY_BASE64 | Base64 of the API private key P8 |

The Firebase plist and provisioning profile must both match the registered
bundle ID `org.negaautism.mobile`. No real client configuration or signing material belongs in Git.
Configure the APNs authentication key in Firebase Cloud Messaging for iOS push
notifications. Do not send real notifications as a build validation step.

## Build and distribute

Run **iOS build and TestFlight** from Actions with publish enabled for analysis,
synthetic tests, signed IPA verification and App Store Connect upload. Disabling
publish provides an optional unsigned compilation check. The build number
uses the monotonically increasing GitHub workflow run number. Start a new run
for each upload; rerunning a previously delivered run repeats its build number.
Flutter 3.47.8 preserves the repository's required security floor.

After upload, wait for Apple processing, answer export-compliance questions,
complete beta metadata and assign the build to the intended TestFlight group.
External testing may require Apple beta review. Upload success alone does not
mean testers can install the app. Confirm processing and tester availability
in App Store Connect before reporting publication.

Validation pending: first macOS build, launch on iPhone, Firebase sign-in,
directory browsing, logo picker and notification permissions/token registration.

## Registered account records � October 29, 2026

- Apple App ID: `org.negaautism.mobile`, description NEGA Autism; Push
  Notifications enabled.
- Apple team: `FKR675M7PM`.
- App Store Connect: NEGA Autism, app ID `6828599193`, SKU `negaautism-ios`,
  primary language English (U.S.), iOS, limited app access to the account holder.
- App record: https://appstoreconnect.apple.com/apps/6828599193/distribution
- Firebase: existing `negaautism` project, new Apple app NEGA Autism iOS with the
  same bundle ID. Configuration downloaded through the explicitly approved Chrome fallback and stored as an encrypted Actions secret.
- Dedicated upload key form prepared as NEGA Autism CI with Developer access;
  created by the user as Z8RDRFJ7SN; the downloaded key is validated and stored as an encrypted Actions secret.
- First successful signed build/upload: version 2.1.0 (3), run 40959517253.
  See delivery evidence below.

- Reuse of Alarm Beans' distribution certificate/password was explicitly approved;
  encrypted copies are configured only in NEGA's Actions secrets. Original files
  and Alarm Beans' configuration are unchanged.
- NEGA App Store profile: 1cd7bbe5-f68e-4a36-ac24-32443a959918,
  app org.negaautism.mobile, team FKR675M7PM, production push; configured as an
  encrypted secret. Exported IPA signature/identity checks run before upload.
- First unsigned workflow run 40958513132 was cancelled at the user's request
  to start with a signed build. The workflow is manual-only again.

## First signed build compatibility correction

Run 40958868475 passed analysis, Flutter tests, signing tests and credential
configuration, then failed during automatic SwiftPM migration: firebase_core
3.6.0 could not locate firebase_sdk_version.rb in the migrated package layout.
The project opts out of SwiftPM using Flutter's documented pubspec setting and
uses its existing CocoaPods plugin integration, preserving Firebase versions.
Flutter 3.47.8 requires iOS 15; the project, Podfile and app framework now agree.
The app uses standard HTTPS/Firebase encryption and declares no non-exempt
cryptography. No custom encryption implementation is introduced.

## First iOS delivery

- Source: b055ba7, version 2.1.0, build 3, iOS 15 minimum.
- GitHub Mac run: https://github.com/agawlbb/negaautism_mobile/actions/runs/40959517253
- Flutter analysis and all Flutter tests passed, as did six synthetic signing
  configuration checks. The archive and 24.4 MB IPA were exported successfully.
- Strict signature verification passed along with app/team/build identity,
  distribution profile, production push entitlement and Firebase app checks.
- Apple upload succeeded without errors at 2026-10-29 21:45:40 UTC,
  delivery UUID 5698abe2-3d7f-4996-8b17-9734c875e58d.
- The user approved an internal NEGA Family testers group with the same two
  people as the other app's group, including the required NEGA app access.
  Existing access and role were preserved. Testers were added through Apple's
  UI; internal beta tester records are app-specific and cannot be copied by ID.
- NEGA group ID: c5aba762-58f3-41d7-bf03-b7c1fffa240c.
- Apple processing completed successfully: upload COMPLETE, build VALID,
  non-exempt encryption false, internal state IN_BETA_TESTING. Build 2.1.0 (3)
  is assigned to Family testers with two approved internal testers.
- Firebase messaging API is enabled. No development/production APNs auth key
  or APNs certificate is configured for the new iOS app yet. Push delivery
  requires that separate configuration; enabling the signing entitlement alone
  does not configure Firebase's connection to Apple. No real notifications were
  sent. Physical iPhone acceptance remains a tester task.
