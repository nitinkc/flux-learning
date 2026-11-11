# gitlab-spring-app-flux

A GitLab CI/CD learning repo: a minimal Spring Boot service shipped through
a **real pipeline** — Maven tests → rootless kaniko image build → Helm chart
packaging → gated deploys to dev/prod namespaces with one-click rollback —
plus the GitOps (`HelmRelease`) alternative.

## Repo layout

```
├── app/                    # minimal Spring Boot service (/api/hello, actuator probes)
│   ├── Dockerfile          # multi-stage: maven build → jre, non-root
│   └── pom.xml
├── chart/spring-app/       # Helm chart (values-dev.yaml / values-prod.yaml)
├── deploy/
│   ├── namespace.yaml      # dev + prod namespaces
│   └── flux/helmrelease.yaml  # pull-model (GitOps) alternative to push deploys
├── .gitlab-ci.yml          # pipeline entry point — includes the stage files below
├── .gitlab/ci/             # one file per stage (see docs/05-reusable-pipelines.md)
│   ├── test.yml            #   maven:test
│   ├── build-kaniko.yml    #   build:kaniko → project container registry
│   ├── package-chart.yml   #   chart:package → dist/*.tgz artifact
│   └── deploy.yml          #   deploy:dev (auto) · deploy:prod (manual) · rollback:prod
└── docs/                   # six-lesson course (mkdocs site)
```

## Quick start

```bash
# 1. Try the app locally (no JDK needed — everything builds in Docker)
cd app && docker build -t spring-app:local .
docker run -p 8080:8080 spring-app:local &
curl localhost:8080/api/hello

# 2. Lint the pipeline before pushing
glab ci lint .gitlab-ci.yml

# 3. To deploy, add KUBECONFIG_DATA (base64 kubeconfig, masked+protected)
#    under Settings → CI/CD → Variables — see docs/03-auth-and-identity.md
```

## Docs site

```bash
uv venv
source .venv/bin/activate
uv pip install -r requirements.txt
mkdocs serve   # http://localhost:8000
```

Lesson order: pipeline anatomy → kaniko builds → auth/OIDC → environments &
gates → reusable pipelines → k8s deploys & rollback.

## Pairs with

- `DevOpsLearning` theory 10 (CI/CD concepts) and lab 12 (Orders API
  end-to-end pipeline)
- `KubernetesConcepts` lab 09 (Flux GitOps ordering)
- `HelmCharts` (chart fundamentals this repo's chart builds on)
