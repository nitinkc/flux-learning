# GitLab CI/CD — From Template to Production Pipeline

A hands-on course that turns this repo from GitLab's echo-job template into a
**real pipeline**: Maven tests → kaniko image build → Helm chart packaging →
gated Kubernetes deploys with rollback.

## How this repo works

- **`app/`** — a minimal Spring Boot service (`/api/hello`, actuator health
  probes) used as the pipeline's workload. Builds fully inside Docker — no
  local JDK/Maven needed.
- **`chart/spring-app/`** — the Helm chart the pipeline lints, packages, and
  deploys (`values-dev.yaml` / `values-prod.yaml`).
- **`.gitlab-ci.yml` + `.gitlab/ci/`** — the pipeline, split into one file
  per stage so each lesson maps to a file.
- **`deploy/`** — the GitOps alternative: a `HelmRelease` showing how Flux
  takes over when CI stops pushing.
- **`docs/`** (this site) — the lessons.

## Learning path

| # | Lesson | What you'll be able to do |
|---|--------|---------------------------|
| 1 | [Pipeline anatomy](01-pipeline-anatomy.md) | Read any `.gitlab-ci.yml`; explain stages vs DAG, rules, workflow control |
| 2 | [Container builds](02-container-builds.md) | Build rootless with kaniko; know when dind is (not) acceptable |
| 3 | [Auth & identity](03-auth-and-identity.md) | Use masked/protected variables; explain OIDC→cloud federation (WIF) |
| 4 | [Environments & gates](04-environments-and-gates.md) | Track deployments, add manual approvals, prevent prod races |
| 5 | [Reusable pipelines](05-reusable-pipelines.md) | Compose pipelines with `include`, `extends`, anchors, child pipelines |
| 6 | [Deploy to Kubernetes](06-deploy-to-k8s.md) | Push-deploy with helm, and explain the pull/Flux alternative |

## Prerequisites

- A GitLab project you own (gitlab.com or self-hosted — everything here is
  generic) with shared runners enabled
- For deploy lessons: any Kubernetes cluster reachable from runners
  (minikube works if you run a self-hosted runner; GKE otherwise)
- `helm`, `kubectl` locally for the verify steps

## The muscle-memory loop

Read a lesson → open the matching `.gitlab/ci/*.yml` file → predict what
each key does → run the pipeline → do the *deliberate break* drill at the
end of the lesson.

!!! tip "Where this leads"
    The capstone pipeline you end with — build, scan, package, gated deploy,
    one-click rollback — is the same shape used to ship real services to
    GKE. Pair with `KubernetesConcepts` lab 09 (Flux ordering) for the
    GitOps half of the story.
