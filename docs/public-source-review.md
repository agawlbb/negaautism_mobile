# Privacy and source-publication review

The repository is private following the October 29, 2026 privacy review. Keep it
private until the project owner explicitly authorizes public visibility again.
Original source/documentation remain AGPL-3.0-only; branding and artwork retain
separate rights as described in NOTICE.md.

## Completed scrub

The prior audit checked credential patterns but missed personal commit metadata.
The subsequent review used Gitleaks 8.30.1 with default rules, recursive decoding,
and archive inspection, plus an independent full-object audit of text, binary
metadata, commit identities/messages, file paths, URLs and personal-data patterns.
Gitleaks identified two historical Google client API-key additions, both inside
Firebase client configuration. No other credential findings were detected.
These scans are bounded evidence and do not prove absence of every possible secret.

All 40 pre-scrub commits were retained with their order, parent relationships,
authorship name and dates; author and committer emails now use the contributor's
GitHub noreply address. Personal machine names and home-directory paths were
removed throughout historical documentation. The Firebase client configuration
was removed from every historical tree and replaced at the tip with a placeholder
example. Local builds must supply their own ignored configuration.

Nine unique historical PNG blobs had text, EXIF, XMP or timestamp chunks removed.
Decoded RGBA pixels and dimensions were verified unchanged. The bundled WebP
illustration has no EXIF/XMP payload. Application source, tests, dependency locks,
package identities and useful commit history are preserved. Only a source-code
comment using a personal-domain example was generalized.

The GitHub review found one branch, no tags, no pull requests, no releases,
no Actions runs/artifacts/caches/workflows, no deployments, no webhooks, no forks,
and disabled wiki/discussions. Eight issues contain task titles only, with no
bodies or comments. No sensitive issue content required editing.

## Recovery and other checkouts

A complete original Git bundle and pre-rewrite ref list were verified and stored
outside this checkout in an access-restricted private recovery directory. The
old-to-new commit map and detailed redacted scanner evidence are kept there too.
Never publish those recovery files or use them as an active workspace.

This is an authorized history rewrite. Other laptop/VPS/cloud clones must not
merge or push the old history back. Fetch the rewritten default, preserve any
unique work privately, and reapply reviewed changes onto the new history using
the private commit map as needed. Do not blindly pull or force push old branches.
Existing app identifiers, public service endpoints and public GitHub handles are
retained because they are application identity/configuration rather than secrets.

History rewriting cannot revoke previously downloaded copies or guarantee removal
of GitHub-retained old commit objects/caches. The repository stays private. Do not
reopen it publicly without accounting for those residual copies.

## Local checks

Run Gitleaks locally (no GitHub runner is configured):

```sh
gitleaks git . --log-opts=--all --redact=100 --max-decode-depth=5 --max-archive-depth=3
```

The repository scanner configuration extends upstream rules with personal-email
and local-home-directory checks. Allowlisted example-domain/noreply addresses
are synthetic or intended for publication. Keep audit reports in an ignored
output directory and never commit unredacted findings.

Validation includes a per-commit old/new tree comparison, unchanged test/lockfile
checks, exact license comparison, pixel equality checks, Git whitespace and object
integrity checks, full-history privacy scans, and a fresh remote-clone scan.
No application build, device installation, notification, credential rotation,
backend deployment or dependency upgrade is part of this scrub.
