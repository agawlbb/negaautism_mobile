# Public source review — October 29, 2026

Purpose: prepare the existing mobile application repository for public source
release under AGPL-3.0-only, matching Coffey Table Recipes and FanControl.
Task purpose: prepare AGPL public source licensing.
Base: fetched origin/master e81044247762d9fce23b0e87ac76fcab6f92bf90.
Canonical repository: https://github.com/agawlbb/negaautism_mobile
Canonical laptop checkout: <canonical mobile checkout>.

## History and publication checks

The remote had one branch (master), no tags, no Actions workflows, and no
repository webhooks at review time. Eight issue records contain only short task titles, with no bodies or comments; there are no GitHub releases. No active local hooks were found. Local
feature branch refs point into the same reviewed history. All 39 reachable
commits were inspected by historical path inventory and blob pattern checks.
No private-key headers, service-account markers, GitHub tokens, AWS access-key
IDs, OpenAI project/service keys, or quoted password assignments were detected.
No historical keystore, signing-properties, private-key, or packaged-app path
was found. Pattern scanning is bounded evidence, not a guarantee of absence.

The tracked Firebase file contains Android client identifiers/API configuration;
it is not a service-account key. It remains available for the existing app.
Signing material created for the recent APK lives outside this repository.
Future private material and generated distributions have explicit ignore rules.

No history rewrite or replacement repository is justified by these findings.
Preserve the existing authorship and useful history. Do not republish private
recovery archives, local configuration, generated output, or unrelated projects.

## Scope and remaining checks

LICENSE is copied verbatim from Coffey Table Recipes. NOTICE.md scopes original
source/documentation, retains dependency licenses, and reserves artwork/branding
rights separately, as explicitly requested by the project owner. No claim of third-party asset ownership is made.

Changes are documentation, license text, and ignore rules only. Review includes
Git whitespace validation, exact license comparison, ignore-rule checks, and
verification that application source and dependency locks are unchanged.
No app build, installation, notification, hosted backend change, deployment,
credential rotation, or dependency upgrade is part of this work.
