---
name: fix-vulnerable
description: Fixes failures reported by the vulnerable workflow, which runs osv-scanner, flake-checker and zizmor. Use when the vulnerable workflow fails, or when asked about an OSV or GHSA advisory, an outdated nixpkgs input or a zizmor finding.
---

# Fix Vulnerable

The `vulnerable` workflow runs weekly in each forge directory (`.github`, `.gitea`, `.forgejo`, `.tangled`) that exists, with a job for each tool. Tangled runs each tool as its own workflow (`vulnerable-nix`, `vulnerable-kotlin`) and skips zizmor, which only audits Actions workflows. Read the failed job's log to find which tool failed and why, then reproduce it locally in the `vulnerable` dev shell:

```sh
nix develop .#vulnerable -c osv-scanner scan source -r .
nix develop .#vulnerable -c flake-checker -f
nix develop .#vulnerable -c zizmor .github/workflows
```

## osv-scanner

osv-scanner reads the locked dependencies in `gradle.lockfile`, which lists every resolved version, including transitive ones, and the configurations that use it. Renovate opens automerging fix PRs for vulnerable direct dependencies, so check for an open Renovate PR first. A failure without one is usually a transitive dependency. The report names the vulnerable package and the fixed version.

1. Find what pulls in the vulnerable package. The configuration is named after the package's entry in `gradle.lockfile`:

   ```sh
   nix develop -c gradle dependencyInsight --dependency <module> --configuration <configuration>
   ```

2. If a newer version of the direct dependency (or the Kotlin plugin in `build.gradle.kts`) pulls in the patched version, update it there.
3. Otherwise, constrain the transitive dependency in `build.gradle.kts`, with a `because` explaining why. A constraint on `implementation` applies to the compile and runtime classpaths, and does nothing when the module isn't pulled in:

   ```kotlin
   dependencies {
       constraints {
           implementation("group:module:1.2.3") {
               because("1.2.2 has GHSA-0000-0000-0000")
           }
       }
   }
   ```

4. Regenerate `gradle.lockfile` and `deps.json`, which the Nix build uses to fetch the dependencies, with `nix run .#update-deps`. Commit both. To only move a locked version that is below what its requirements allow, run `nix develop -c gradle installDist test --update-locks <group>:<module>` instead.
5. Only when no patched version exists, or the vulnerable code is unreachable, ignore the advisory in `osv-scanner.toml` next to `gradle.lockfile`, with a reason, and tell the user. Ignoring an ID also ignores its aliases, and `ignoreUntil` is an optional date after which it is reported again:

   ```toml
   [[IgnoredVulns]]
   id = "GHSA-0000-0000-0000"
   ignoreUntil = 2030-01-01
   reason = "reason"
   ```

## flake-checker

flake-checker fails when a nixpkgs input is outdated (over 30 days old), not owned by `NixOS`, or tracks an unsupported branch. Renovate only updates Nix inputs during its weekly lock file maintenance, which automerges.

1. Check for an open Renovate lock file maintenance PR. If one exists, its checks are probably failing, so fix the failure on that PR's branch instead of opening a competing one.
2. Otherwise run `nix flake update`, then fix anything the update breaks.
3. For an owner or branch failure, change the input's URL in `flake.nix` to a supported `NixOS/nixpkgs` branch.

## zizmor

zizmor audits the workflows for security issues. CI runs its online audits with a GitHub token. Locally, set `GH_TOKEN` to enable them, for example with `GH_TOKEN=$(gh auth token)`, or they're skipped.

1. Fix the finding in every forge directory that has the workflow, not only the one that failed. The forges' workflows differ: GitHub and Gitea set `permissions`, while Forgejo doesn't support them and uses `enable-openid-connect`. Adapt the fix to each forge rather than copying it.
2. Pinned action updates (`unpinned-uses`, known vulnerable versions) are Renovate's job, so check for an open Renovate PR first.
3. Only when a finding doesn't apply to a forge, ignore it with an inline `# zizmor: ignore[<audit>]` comment on the flagged line, as the Forgejo workflows do for `excessive-permissions`.

## Finish

Run `nix flake check`, and confirm each tool that failed now passes locally.
