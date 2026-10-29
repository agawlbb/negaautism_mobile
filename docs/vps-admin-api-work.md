# VPS admin and mobile API migration

Working branch: `feature/vps-admin-api`. Base: `7b474434b5d9e96205313fc855b62ab6edb0bbc9`.

Purpose: implement VPS versions of existing mobile API capabilities and a native
admin experience based on website capabilities, preserving claim boundaries.
No deployment, app build or installation is part of this source checkpoint.

First slice: public provider/event reads, verified TLS database adapter, and mobile
read endpoint migration. Website writes, logos and PDF generation remain hosted.
Do not distribute this mobile source until VPS database access and endpoints are
configured, deployed and verified. No automatic fallback to the hosted reads.

Next: authenticated profile/notifications and event writes; provider writes and
hosted asset/PDF contracts; native admin dashboard, approval queues, taxonomy and
Firebase user management. Inventory the separate forum app before migrating it.
Database host, account grants, VPS IP allowlisting and TLS connectivity remain
unverified; do not test against production data in development.

Validation: backend suite passes 42 tests, including API filters, public-field
boundaries, private error responses, required TLS and missing configuration.
Flutter analysis passes and all 43 mobile tests pass using the existing enforced
lockfile and offline cache. No production database connections were attempted.
This is an incomplete task checkpoint, not an integration/release candidate.

## Authenticated API and admin continuation

Implemented VPS profile loading, device-specific notification registration,
event writes, hosted provider-save gateway, provider/review approvals and review
deletion, plus category/county CRUD. The mobile app now uses these VPS endpoints
and provides an Admin menu, pending/all approval queues, provider add/edit,
category/county dialogs and moderator event management. Permissions are checked
against signed tokens and current Firebase account permissions; admin is derived
from management/moderator privileges as on the website.

Provider/logo writes remain owned by the existing hosted save endpoint behind
the VPS gateway. The website admin handlers were not copied or deployed.
No new package dependencies were added in this continuation. No live provider,
event, review, notification or user mutations were used for validation.

Remaining: user management, provider deletion, PDF downloads, category-logo uploads,
the separate forum application, deployment and real administrator/device checks.
This task branch remains incomplete and must not be merged or distributed yet.

Continuation validation: 58 backend tests and 50 mobile tests pass; Flutter
analysis and Git whitespace checks pass. These commits remain local, unmerged
and undeployed. Full capability parity remains outstanding as listed above.
