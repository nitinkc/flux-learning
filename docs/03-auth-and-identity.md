# 3. Auth & identity: variables, OIDC, and keyless cloud access

## Why this matters

The most common pipeline security failure is a long-lived credential checked
into CI settings — or worse, into the repo. Modern pipelines authenticate
with **identity, not secrets**: short-lived tokens the platform issues per
job. Understand both layers and you'll never need a service-account JSON
key again.

## Layer 1: CI/CD variables

**Settings → CI/CD → Variables.** Three dimensions matter:

| Flag | Effect |
|------|--------|
| **Masked** | redacted in job logs (`***`); requires a log-safe value format |
| **Protected** | only exposed to pipelines on protected branches/tags — your `deploy:prod` credential should be both |
| **File vs Variable** | `File` type writes the value to a temp file and sets the var to its path — ideal for kubeconfigs/JSON |
| **Scope** | project vs group vs instance — group vars let all projects inherit shared config |

This repo needs exactly one variable to deploy:

```
KUBECONFIG_DATA   (type: Variable, masked + protected)
                  = base64 -i ~/.kube/config | tr -d '\n'
```

`.gitlab/ci/deploy.yml` decodes it in `before_script`. Nothing credential
shaped ever appears in the repo or the logs.

## Layer 2: OIDC federation (the keyless pattern)

GitLab can issue each job a signed JWT (`id_tokens`) that a cloud provider
trusts — the job exchanges it for a short-lived cloud credential. No stored
key to leak or rotate.

```yaml
gcp-auth:
  id_tokens:
    GCP_AUD:                                    # claim baked into the token
      aud: https://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/POOL/providers/PROVIDER
  script:
    # exchange the JWT for a federated token, then docker/helm/gcloud auth
    - gcloud iam workload-identity-pools create-cred-config ...
```

> **GCP twin:** this is Workload Identity Federation — the pipeline-side
> mirror of the in-cluster Workload Identity already used in
> `terraform-concepts/acme-sampleapp-multirepo` (KSA ↔ GSA binding). Same
> principle: *an identity you are, not a key you hold.*

## The hierarchy, memorized

```
best   → OIDC id_token → short-lived federated cred   (nothing stored)
better → masked+protected CI var holding a scoped cred (rotated regularly)
ok     → CI variable (never logged, low privilege)
never  → secrets in the repo, echo'd in logs, or in Docker image layers
```

GitLab's secret-detection template (added in the security phase) fails
pipelines on the bottom row automatically.

## Hands-on

1. Create `KUBECONFIG_DATA` as above; run `deploy:dev`; search the job log
   for `kube` — confirm nothing sensitive printed.
2. Unmask it (temporary!) and re-run — the raw kubeconfig base64 scrolls by.
   Re-mask. That *is* the drill.
3. Push a branch, run `deploy:prod` — the job fails: the variable isn't
   available outside the protected `main` branch. That's protected vars
   doing their job.

## Deliberate break & triage

- **Break 1:** `echo $KUBECONFIG_DATA | base64 -d` in a job on a feature
  branch → empty output. Protected vars don't leak to unprotected refs.
- **Break 2:** forget `base64 -d` (use the var directly as kubeconfig) →
  `error: couldn't get version/kind; json parse error`. The encode/decode
  round-trip exists to dodge newline-mangling in CI vars.
- **Break 3:** commit a `kubeconfig` file to the repo → now imagine it in
  `git log` forever. Rotate it, scrub it, add the rule to
  `.gitignore` + a gitleaks job (Phase 2).

## Verify

- [ ] Deploy works with zero secrets in the repo
- [ ] You can explain masked vs protected vs file-type in one line each
- [ ] You can sketch the OIDC trust flow (job → JWT → cloud cred → API call)
