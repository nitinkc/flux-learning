# 2. Container builds: kaniko vs dind

## Why this matters

Building images inside CI means "Docker inside Docker," and the naive way —
the `docker:dind` service — requires **privileged mode**: the build
container gets near-root on the runner host. On shared runners that's a
lateral-movement gift. kaniko builds the image *in userspace* with no
daemon, which is why regulated shops standardize on it.

## How the build job works

`.gitlab/ci/build-kaniko.yml`:

```yaml
build:kaniko:
  image:
    name: gcr.io/kaniko-project/executor:debug
    entrypoint: [""]          # the image's default entrypoint is kaniko itself;
                              # empty it so GitLab can run our shell script
```

Two moving parts:

1. **Registry auth.** kaniko reads `/kaniko/.docker/config.json`. We write
   it from *predefined* variables — `CI_REGISTRY`, `CI_REGISTRY_USER`,
   `CI_REGISTRY_PASSWORD` are injected by GitLab and scoped to the project
   registry. You never create or store a credential yourself.
2. **`--context` / `--dockerfile` / `--destination`.** Context is `app/`
   (respects `app/.dockerignore`), destination is
   `$CI_REGISTRY_IMAGE/spring-app:$CI_COMMIT_SHORT_SHA` — tag by commit, not
   `latest`, so every deploy is traceable to a commit.

## Decision table

| Builder | Privileged? | Cache | Use when |
|---------|------------|-------|----------|
| `docker:dind` | **Yes** — avoid on shared runners | native layer cache | self-hosted runners you fully control |
| **kaniko** | No | `--cache=true` → cache-repo | shared runners, regulated environments |
| buildah/buildkit rootless | No | good | non-GitLab environments |
| GitHub `build-push-action` | runner-managed | `type=gha` | GitHub Actions |

## Dockerfile tricks already doing work for you

`app/Dockerfile` copies `pom.xml` and runs `dependency:go-offline` **before**
copying `src/` — dependencies live in an early layer that only rebuilds when
the pom changes. Source edits reuse the ~200 MB dependency layer. Same trick
as `package-lock.json`-first for Node.

## Hands-on

```bash
# Simulate the build locally (same layers, same result):
cd app && docker build -t spring-app:local .
docker run -p 8080:8080 spring-app:local &
curl localhost:8080/api/hello
# → {"message":"hello from spring-app"}
```

Push a source-only change and time the second pipeline: the Maven layer
cache + the kaniko layer cache should make it dramatically faster.

## Optional: layer caching

kaniko caches layers to a repo when you pass `--cache=true
--cache-repo=$CI_REGISTRY_IMAGE/cache`. On shared runners this is often the
difference between a 40 s and a 4 min build.

## Deliberate break & triage

- **Break 1:** point `--destination` at `${CI_REGISTRY_IMAGE}` with no tag →
  kaniko pushes `latest`; now every environment drifts to whatever built
  last. This is *why* pipelines tag by SHA.
- **Break 2:** delete the `config.json` write step →
  `UNAUTHORIZED: authentication required`. Find where auth was assumed.
- **Break 3:** move `COPY src ./src` above the `dependency:go-offline` line
  → every build re-downloads Maven deps. Watch build time double.

## Verify

- [ ] Image appears under **Deploy → Container Registry** tagged with the SHA
- [ ] You can explain why `entrypoint: [""]` is required
- [ ] You can state the security argument for kaniko in one sentence
