# Repository workflow

## Repository workflow

Canonical repository: `agawlbb/negaautism_mobile`; default branch: `master`.
Follow the VM-wide working procedure in `/home/dev/projects/AGENTS.md`.
Use the existing checkout on `master`, one task at a time; no routine task
branches, extra worktrees or ownership claims. Complete the requested outcome,
including deployment when applicable, then commit and push to `master`.
Use only relevant checks; do not repeat passing checks without a concrete reason.
Questions and status checks are read-only. Preserve unrelated work and credentials.

## Project boundaries

- Keep this application's source and history separate from `agawlbb/negaautism.org` and the other NEGA application repository. Coordinate changes to shared API contracts with affected tasks.
- Preserve existing security, SDK and validation rules in [README.md](README.md) and [SECURITY-VALIDATION.md](SECURITY-VALIDATION.md). This documentation update does not authorize builds, releases, deployment, dependency changes or changes to installed apps.
- Never commit credentials, private configuration, signing material, personal data or generated packages. Preserve useful tests, release tags and recovery evidence.

## Privacy rewrite — October 29, 2026

- Keep this repository private until the user explicitly requests public visibility.
- Use the repository-local Git identity `agawlbb` with
  `23645115+agawlbb@users.noreply.github.com` for new commits. Do not restore a
  personal email in commit metadata or add a mailmap containing private addresses.
- The complete prior history was rewritten for privacy. Existing laptop/VPS/cloud
  clones must preserve unique work privately and rebase/reapply accepted work onto
  the fetched rewritten default. Never merge or push the pre-scrub history back.
  The private recovery area contains the verified bundle and old/new commit map.
- Real Firebase client configuration is ignored and supplied locally. Commit only
  the placeholder example. Keep private recovery files outside source checkouts.
- Run the local checks in `docs/public-source-review.md` before republishing source.

## Fresh source repository

- The canonical GitHub URL above now identifies a fresh independent repository
  containing only scrubbed history. Keep it private pending explicit user approval.
- The former GitHub repository and its issue tracker are retained privately at
  `agawlbb/negaautism_mobile-private-archive-20261029`. Never publish that archive,
  push it into the canonical repository, or use it as an active workspace.
- Follow `docs/repository-migration.md` when resuming work in an older clone.
