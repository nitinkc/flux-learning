# 8. Porting to GitHub Actions

## Why this matters

Pipelines outlive platforms. Knowing the *concepts* behind this repo's
GitLab pipeline — ordering, change detection, manual gates, OIDC signing —
means you can rebuild it on any CI system. `.github/workflows/` contains a
working GitHub Actions port of the entire pipeline; this lesson is the
mapping table that explains it.

## The concept map

| GitLab CI | GitHub Actions |
|---|---|
| `.gitlab-ci.yml` + `include: local:` | `.github/workflows/*.yml` — `workflow_call` reusable workflows |
| `stages:` | Nothing — ordering comes entirely from `needs:` (jobs parallelize by default) |
| `workflow.rules` (MR vs branch vs tag) | `on: pull_request` / `on: push` triggers |
| `rules: changes:` | `paths:` on the trigger, or `dorny/paths-filter` for per-job change detection |
| `image:` per job | `container:` per job, or tool-setup actions (`setup-java`, `setup-helm`) |
| `CI_REGISTRY_*` predefined vars | `ghcr.io` + `GITHUB_TOKEN` — nothing to configure |
| `CI_COMMIT_SHORT_SHA` | `${{ github.sha }}` (full SHA; `${GITHUB_SHA::7}` in shell for short) |
| `cache:` | `actions/cache`, or `cache: maven` inside `setup-java` |
| `artifacts:` / `reports:junit` | `actions/upload-artifact` + `dorny/test-reporter` |
| `when: manual` | `environment:` with *required reviewers* (Settings → Environments) |
| `resource_group: prod` | `concurrency: prod` |
| `id_tokens:` (OIDC) | `permissions: id-token: write` |
| Secret-Detection template | `gitleaks/gitleaks-action` |
| `allow_failure: true` | `continue-on-error: true` |
| kaniko executor image | `docker/build-push-action` — runners have a daemon, no kaniko needed |
| protected CI variable | environment-scoped secret |

## File-for-file

```
.gitlab-ci.yml                  →  .github/workflows/ci.yml
.gitlab/ci/test.yml             →  .github/workflows/reusable-test.yml
.gitlab/ci/build-kaniko.yml     →  .github/workflows/reusable-build.yml
.gitlab/ci/security.yml         →  .github/workflows/reusable-security.yml
.gitlab/ci/package-chart.yml    →  .github/workflows/reusable-package.yml
.gitlab/ci/deploy.yml           →  .github/workflows/reusable-deploy.yml
                                   .github/workflows/rollback.yml
```

The `.deploy-base` anchor becomes a single parameterized reusable
workflow: `deploy-dev` and `deploy-prod` are two *call sites* passing
different typed `inputs:` — the same pattern as GitLab CI/CD components.

## The three genuinely different things

### 1. No stages — `needs` is the only ordering

GitLab runs stage-by-stage; a job with no `needs` waits for the whole
previous stage. GitHub runs *everything* in parallel unless `needs` says
otherwise. The port expresses the whole DAG explicitly — including the
GitLab `optional: true` semantics, which become an `always()` + result
check:

```yaml
if: >-
  always() &&
  needs.changes.outputs.build == 'true' &&
  (needs.test.result == 'success' || needs.test.result == 'skipped')
```

Without `always()`, a job whose need was *skipped* is itself skipped —
that's the gotcha behind every "optional needs" translation.

### 2. `rules: changes:` is per-job; `paths:` is per-workflow

GitHub's native `paths:` filter decides whether the *whole workflow* runs.
Per-job granularity needs a fan-out job (`dorny/paths-filter`) that
exports flags the downstream jobs read via `needs.changes.outputs.*`.

### 3. Manual gates live on the environment, not the job

GitLab's `when: manual` draws a button inside the pipeline. GitHub instead
pauses a job on an `environment:` that has *required reviewers*
configured — set them under **Settings → Environments → prod**. Same
outcome (pipeline waits for a human), different plumbing.

The `rollback:prod` job has no in-pipeline equivalent, so it becomes a
standalone `workflow_dispatch` workflow — run it on demand from the
Actions tab. It keeps `environment: prod`, so the same approvals and
secrets apply.

## What you must configure once

- **Secrets:** add `KUBECONFIG_DATA` (base64 kubeconfig). Scope it to the
  `dev`/`prod` environments to reproduce protected-variable semantics.
- **Environments:** create `dev` and `prod`; add required reviewers to
  `prod` to get the `when: manual` gate.
- **Nothing for the registry:** `GITHUB_TOKEN` + `ghcr.io` works out of
  the box. On PRs from forks the token is read-only — pushes to GHCR will
  fail there, same as a fork MR failing to push to a private GitLab
  registry.

## What doesn't port

- **The dedup rule.** GitLab's "skip the branch pipeline when an MR covers
  the commit" has no native twin — the port sidesteps it by triggering
  `push` on `main` only (PR branches are covered by `pull_request`).
- **Merged-results vs merge commit:** subtle, but both platforms test the
  post-merge result by default on MR/PR events, so behavior matches.
