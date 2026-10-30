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
