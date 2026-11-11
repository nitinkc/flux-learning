# 4. Environments & deployment gates

## Why this matters

Without the `environment:` keyword, GitLab just sees jobs that run `helm`.
With it, every deploy becomes a tracked, reviewable, reversible event on the
**Deployments** page — who deployed what, when, from which commit — and
*approvals* become a first-class control instead of a code comment.

## What `environment:` gives you

```yaml
deploy:prod:
  environment:
    name: prod            # shows up under Operate → Environments
    # url: https://app.example.com   # optional: adds a live link/button
    # on_stop: stop:prod             # optional: cleanup job when env is torn down
```

- **Deployment tracking**: each successful job writes a deployment record —
  commit SHA, author, timestamp — visible in the UI and via API.
- **Manual gates**: `rules: - when: manual` makes the job a button. Combined
  with *protected environments* (Settings → CI/CD → Protected environments)
  you can restrict who may click it — the org's real prod-approval control.
- **Serialized prod access**: two pipelines both reaching `deploy:prod`
  race to `helm upgrade` the same release. `resource_group: prod` on the
  job makes them queue — only one prod deploy runs at a time, ever. Add it
  to `deploy:prod` and `rollback:prod` (same group: a rollback must also
  not race a deploy).

```yaml
deploy:prod:
  resource_group: prod
  environment:
    name: prod
  rules:
    - if: '$CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH'
      when: manual        # the gate: a human clicks "play"
```

## Review apps (dynamic environments)

Environments don't have to be fixed names — derive them from the branch:

```yaml
review:
  environment:
    name: review/$CI_COMMIT_REF_SLUG
    url: https://$CI_COMMIT_REF_SLUG.review.example.com
    on_stop: stop_review
  rules:
    - if: '$CI_PIPELINE_SOURCE == "merge_request_event"'
```

Every MR gets an ephemeral namespace/cluster slice; the `on_stop` job
(`helm uninstall`) tears it down when the MR closes. This is the standard
"review app" pattern and the cheapest way to demo changes.

## Hands-on

1. Run the pipeline on `main` — `deploy:prod` sits as a grayed play button.
   Click it → deployment record appears under **Operate → Environments →
   prod** with a history list.
2. Push twice quickly → second pipeline's prod deploy waits on
   `resource_group`.
3. Visit the environment's history → the **Rollback** button re-runs the
   previous successful deploy job; compare with our explicit
   `rollback:prod` (helm history-based — safer for partial upgrades).

## Deliberate break & triage

- **Break 1:** remove `resource_group`, trigger two rapid merges → two
  `helm upgrade` runs interleave; `helm list -n prod` may show
  `pending-upgrade`. `helm history` explains the wedge.
- **Break 2:** give `deploy:dev` `when: manual` → your "automatic" dev flow
  silently stops. Gating is a deliberate choice per environment.
- **Break 3:** point `deploy:prod`'s rules at `always` → MR pipelines now
  expose a prod deploy button to any branch. This is why prod rules gate
  on `$CI_DEFAULT_BRANCH` *and* vars are protected.

## Verify

- [ ] Deployment history shows SHA + author per deploy
- [ ] `deploy:prod` is a manual click and serialized by `resource_group`
- [ ] You can explain the difference between the UI Rollback button and a
      `helm rollback` job
