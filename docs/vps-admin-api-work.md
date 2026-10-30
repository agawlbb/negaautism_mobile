# Direct VPS admin/mobile API task

Working branch: feature/vps-admin-api. Base: 7b474434b5d9e96205313fc855b62ab6edb0bbc9.

Purpose: provide native administrative capabilities and migrate mobile API calls
to the VPS. InMotion supplies only database and logo files; Firebase administration
and PDF generation run on the VPS. No forum work is included.

The VPS owns provider/event/profile/notification writes and review/taxonomy
management. Direct Firebase administration preserves unrelated claims and protects
associated content. Provider PDFs run locally with the existing renderer/fonts/QR
implementation. Logo decoding runs on the VPS; only file storage uses InMotion.
The superseded hosted capability API/forwarders were removed before deployment.
The website has no runtime changes relative to its canonical default.

The private Firebase credential was provisioned on the VPS and verified by a
read-only Google account request. No credential value or account data was logged.
No production content/user mutation, app build, installation or deployment ran.
A separate development image validates the local PDF runtime without network or
credentials. Native Android/iOS document-saving code still needs build/device
validation. Rollout must stage the private files and update the service environment
before the prepared backend and mobile source can be used.

See negaautism-vps/docs/mobile-admin-api.md and the existing vps_admin RUNBOOK
section for contracts and the matching proposed runtime configuration.

Validation: 81 VPS tests pass, including real local PDF content/page checks.
The original PHP renderer and maximum-50-page booklet regressions pass. The
separate image builds and passes non-root/read-only, no-network/no-secret PDF
and timezone checks. Read-only Firebase lookup and IAM verification confirm
account metadata access and user read/update/delete permissions. No accounts,
policies, provider records or live logo files were mutated. The mobile code is
unchanged; its previous 54-test/analysis result remains the client checkpoint.
All changes remain on local task branches, unmerged and undeployed.

## Suspicious signup review

Continues on the same feature branch from `0a3b6ab`. User managers have a
"Review suspicious signups" admin action. It shows up to 50 flagged names with
email, username and reasons; reviewers uncheck legitimate users before confirming
bulk deletion. Kept accounts are skipped for this review session, not permanently
allowlisted. The VPS rechecks selected names, management permissions and content
references. Per-account results distinguish deleted accounts from conflicts or
unconfirmed outcomes; failures require refresh and never cause automatic retries.
This source update requires the matching backend cleanup routes before app rollout.
Synthetic tests cover confirmation, keeping accounts, pagination and uncertain
failures. No production account scan, deletion, app build or deployment is included.

## Thirty-day deletion waiting period

Supersedes the immediate deletion behavior described above. Both individual and
bulk user deletion requests now schedule removal in 30 days. Pending users are
hidden by default, with an explicit "Show pending deletions" switch and UTC
expiry dates in Manage users. The signup-review queue excludes pending accounts.
The backend's daily 07:00 UTC worker eventually removes due profiles, notification
registrations and Firebase accounts while retaining staff/content protections.
Scheduling leaves both accounts intact; repeat requests do not extend deadlines.
This requires the matching backend source update. Website controls remain unchanged.
No production account was marked or deleted and no new app build/deployment ran.

The pending-deletion view now lists pending accounts alone. Its Undelete action
clears the pending flag and deadline through the VPS, restoring the normal user
listing and cancelling cleanup. The backend locks the profile against concurrent
purge and refuses to clear the mark if Google already permanently removed the
account. This changes no website controls and performs no production mutations.

Bulk cleanup now submits one selected list and the backend uses a batched Google
lookup, batched relationship checks, one SQL update and one transaction. The app
uses Delete labels, a count-only confirmation, and compact account details with
no introductory paragraph or flag explanations. The 30-day delay and Undelete
are preserved. These source changes are not a deployment or app build.
