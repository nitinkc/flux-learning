# 6. Deploy to Kubernetes: push vs pull

## Why this matters

There are two ways CI reaches a cluster, and picking between them is a real
architecture decision:

- **Push** — the pipeline runs `helm upgrade` with a kubeconfig/agent
  connection. Simple, synchronous, the model in this repo's `deploy:*` jobs.
- **Pull (GitOps)** — CI only publishes the image/chart and updates a
  release repo; an in-cluster agent (Flux, Argo CD, or the GitLab agent for
  Kubernetes) reconciles. The cluster's credentials never leave the
  cluster.

Regulated environments strongly prefer pull: no pipeline holds prod
kubeconfig at all.

## How the deploy jobs work

`.gitlab/ci/deploy.yml` — the `alpine/k8s` image bundles `kubectl`, `helm`,
`kustomize`:

```yaml
script:
  - helm upgrade --install spring-app "dist/spring-app-*.tgz"
    --namespace dev --create-namespace
    -f ${CHART_DIR}/values-dev.yaml
    --set image.repository=${CI_REGISTRY_IMAGE}/spring-app
    --set image.tag=${CI_COMMIT_SHORT_SHA}
    --wait --timeout 3m
```

Anatomy of the command:

| Flag | Why |
|------|-----|
| `upgrade --install` | idempotent: creates the release on first run, upgrades after |
| `--namespace dev --create-namespace` | env isolation by namespace (values-dev/prod.yaml match) |
| `-f values-dev.yaml` | environment values layered over defaults |
| `--set image.tag=$CI_COMMIT_SHORT_SHA` | pins the exact image kaniko pushed — the pipeline's contract |
| `--wait --timeout 3m` | don't report success until pods are Ready; timeout turns a bad image into a failed deploy instead of a green lie |
| artifact `dist/spring-app-*.tgz` | arrives via `needs: ["chart:package"]` — the packaged, linted chart |

## Auth: two options

1. **`KUBECONFIG_DATA`** (this repo's default) — base64 kubeconfig, masked +
   protected. Works everywhere; the cred lives in CI settings.
2. **GitLab agent for Kubernetes** — an agent (`agentk`) runs in-cluster and
   GitLab proxies `kubectl`/`helm` through it via `KUBECONFIG` context
   `gitlab-agent`. The pipeline holds *no* cluster credential — closer to
   the pull model's security. (DaVita-scale setups use this pattern via
   KAS/k8s_proxy.)

## The GitOps alternative

`deploy/flux/helmrelease.yaml` shows the pull model: commit a `HelmRelease`
to a repo Flux watches, and the *cluster* applies it. CI's contract shrinks
to: build → test → scan → push image/chart → bump the release file. Pair
with `KubernetesConcepts` lab 09 (Flux ordering) and the HelmCharts flux
section.

## Rollback

```yaml
rollback:prod:
  script:
    - helm history spring-app --namespace prod
    - helm rollback spring-app --namespace prod --wait
```

`helm rollback` (no revision arg) returns to the previous revision —
fast, because the prior ReplicaSet is still warm. In GitOps mode rollback
is `git revert` + Flux reconciliation; in push mode it's this job.

## Deliberate break & triage — the failed-rollout drill

This is the money drill (index "stage 8"):

1. Deploy a bad image: push a commit that sets
   `--set image.tag=does-not-exist` (or edit the deploy script's tag to a
   bogus SHA).
2. Watch: `--wait` times out at 3m, the job **fails**, `deploy:prod` never
   offered for that pipeline. Without `--wait` the job would go green while
   pods `ImagePullBackOff` forever.
3. Check `kubectl -n dev get pods` → `ImagePullBackOff`;
   `helm history` → release stuck at `pending-upgrade`.
4. Recover with `rollback:dev`-style job or
   `helm rollback spring-app -n dev --cleanup-on-fail --wait`.
5. Fix the tag, redeploy, confirm Ready.

- **Break 2:** run `helm upgrade` while a previous release is wedged in
  `pending-upgrade` → `another operation (install/upgrade/rollback) is in
  progress`. Unlock with `helm rollback` or `helm uninstall` on the wedged
  release.
- **Break 3:** `helm upgrade` (no `--install`) on a fresh namespace →
  `Error: release: not found`. Idempotency is why `--install` is default.

## Verify

- [ ] A deploy to `dev` is fully automated on merge to `main`
- [ ] A broken image produces a *failed job*, not a green one (`--wait`)
- [ ] You performed a real `helm rollback` and can explain what happened
      in the cluster (old ReplicaSet scaled back up)
- [ ] You can articulate push vs pull trade-offs in one paragraph each
