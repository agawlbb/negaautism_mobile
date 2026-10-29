# Fresh private repository — October 29, 2026

The user requested a fresh private repository containing only the scrubbed history,
with the previous repository retained privately for recovery. The replacement is
an independent repository, not a GitHub fork or a mirror of the old object store.

- Canonical source: https://github.com/agawlbb/negaautism_mobile
- Default branch: master
- Canonical laptop folder: the existing mobile application checkout.
- Private original/archive: https://github.com/agawlbb/negaautism_mobile-private-archive-20261029
- The original issue tracker remains in that private archive. Its eight issues
  contain titles only, with no comments or bodies. They were preserved in place.
- Keep both repositories private until the user explicitly approves publishing
  the new source repository. Never publish the recovery archive.

Task: privacy/fresh-repository-2026-10-29, based on fetched scrubbed origin/master
at 644e001c4da0ae8c8dc4890fd4ec6ba6fe11489e. This task changes documentation only;
the application source, tests, assets, dependency locks and AGPL license remain
unchanged. Local Firebase client configuration remains ignored and privately held.

## Verification

The new repository receives only the scrubbed master history. Local-only branches,
private configuration, recovery refs and original commit objects are not pushed.
Before migration, the new repository is checked for an independent identity,
private visibility, and absence of push-triggered workflows/webhooks.

After publishing the scrubbed branch, a fresh GitHub clone is scanned with
Gitleaks and the personal-data checks. Its reachable commit IDs are compared with
the scrubbed source; all original pre-scrub commit IDs are checked against the new
GitHub repository to confirm they cannot be retrieved there. The private archive
retains its original GitHub identity and issue tracker. Migration evidence and
original/scrubbed commit maps remain only in private recovery storage.

## Other working copies

Existing laptop/VPS/cloud clones must fetch and verify the rewritten default,
preserve unique work privately, and reapply accepted work onto the scrubbed line.
Never merge or push pre-scrub commits back. A fresh clone of the canonical source
is the clearest option for a checkout that still contains old history. Do not use
the private archive as an active remote or development workspace.

Source publication approval is separate. This migration does not build an app,
install it, deploy backend changes, change credentials, or enable a GitHub runner.
