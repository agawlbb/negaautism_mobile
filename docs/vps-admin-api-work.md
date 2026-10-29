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
