# 5. Reusable pipelines: include, extends, anchors, children

## Why this matters

One 500-line `.gitlab-ci.yml` is unmaintainable; every org eventually splits
and reuses pipeline config. GitLab gives you *four* reuse mechanisms that
solve different problems — picking the wrong one is a classic interview
stumper and a real maintenance smell.

## The four mechanisms (decision table)

| Mechanism | Scope | Solves |
|-----------|-------|--------|
| `include:` | file-level | split config into modules; share org templates |
| `extends:` | job-level | inherit and override a template job |
| YAML anchors `&`/`*`/`<<:` | within one file | dedupe repeated blocks (used by `.deploy-base`) |
| `trigger:` child pipeline | pipeline-level | monorepo: run only the sub-pipeline that changed |

## This repo's split

```yaml
# .gitlab-ci.yml
include:
  - local: '.gitlab/ci/test.yml'
  - local: '.gitlab/ci/build-kaniko.yml'
  - local: '.gitlab/ci/package-chart.yml'
  - local: '.gitlab/ci/deploy.yml'
```

Each stage file is independently readable and the root file stays a table
of contents. `include:` variants to know: `local` (this repo), `project`
(another repo + `ref`), `remote` (URL), `template` (GitLab-built security
templates — Phase 2 uses them), `component` (CI/CD catalog, with typed
`inputs:`).

## extends vs anchors

Both dedupe job definitions; differ subtly:

```yaml
.job-template:              # hidden job (leading dot) = template
  image: alpine/k8s:1.31.2
  before_script: [setup-kubeconfig.sh]

deploy:dev:
  extends: .job-template    # merges + overrides; crosses include boundaries
```

```yaml
.deploy-base: &deploy-base  # anchor on a hidden job
  stage: deploy

deploy:prod:
  <<: *deploy-base          # pure YAML merge — same file only
```

Use **`extends`** for cross-file templates; **anchors** for same-file
shorthand. (`!reference` lets a script line be borrowed selectively.)

## Child pipelines

```yaml
trigger-sub:
  trigger:
    include: backend/.gitlab-ci.yml   # runs as a downstream pipeline
    strategy: depend                  # parent waits for child result
  rules:
    - changes: [backend/**/*]
```

Monorepo pattern: parent pipeline fans out to per-service child pipelines
scoped by `changes:` — each child reports status upstream with
`strategy: depend`.

## Hands-on

1. Refactor drill: inline all four `.gitlab/ci/*.yml` into one file, lint
   it, then re-split. The include version is what you'd actually maintain.
2. Convert `.deploy-base` from anchor to `extends:` — verify
   `glab ci lint` and the rendered job list are unchanged.
3. Add a `project:` include pointing at a second repo you own with a shared
   `docker-build.yml` template — the beginning of an org template library.

## Deliberate break & triage

- **Break 1:** include `deploy.yml` twice → `glab ci lint` flags duplicate
  job names (second include silently wins in some versions — worse!).
- **Break 2:** a job in `test.yml` `extends:` a `.template` defined only in
  `deploy.yml`, but `test.yml` doesn't include it → template not found.
  `extends` resolves post-include-merge, but readability suffers — keep
  templates near consumers or in a shared include.
- **Break 3:** anchor `when: manual` onto the same job as `rules:` → lint
  error *"when may not be used with rules"*. They are mutually exclusive
  job keys.

## Verify

- [ ] You can name when each of the 4 mechanisms is correct
- [ ] The pipeline lints with includes split or inlined
- [ ] You can draw where artifacts/variables flow between parent and child
