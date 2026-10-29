# iOS and TestFlight

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

Run **iOS build and TestFlight** from Actions with publish disabled for analysis,
synthetic tests, and an unsigned device build. Enable publish for a signed IPA
and App Store Connect upload after the first build succeeds. The build number
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

## Registered account records — October 29, 2026

- Apple App ID: `org.negaautism.mobile`, description NEGA Autism; Push
  Notifications enabled.
- Apple team: `FKR675M7PM`.
- App Store Connect: NEGA Autism, app ID `6828599193`, SKU `negaautism-ios`,
  primary language English (U.S.), iOS, limited app access to the account holder.
- App record: https://appstoreconnect.apple.com/apps/6828599193/distribution
- Firebase: existing `negaautism` project, new Apple app NEGA Autism iOS with the
  same bundle ID. Configuration download/import remains pending.
- Dedicated upload key form prepared as NEGA Autism CI with Developer access;
  generation/download and encrypted GitHub secret storage remain pending.
- No Mac build or TestFlight upload has run. There are no uploaded builds yet.
