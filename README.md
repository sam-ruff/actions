# actions

Reusable GitHub Actions workflows for Rust services with a web UI, static musl release binaries, container images, Zensical docs and semantic-release. Every job runs on a self-hosted runner pool, and none of them will fall back to a GitHub-hosted runner.

Call them at `@v1`. That tag moves to each new 1.x release. For a fixed version, pin a full tag such as `@v1.0.0` or a commit SHA.

## Before you call these

The workflows run on self-hosted runners, so a pull request from a fork would run its code on your machines. Under Settings, Actions, General, set "Fork pull request workflows from outside collaborators" to "Require approval for all outside collaborators". As a second line of defence, every CI workflow skips pull requests from forks unless you set `allow-fork-pull-requests: true`. A fork can edit your caller workflow, though, so the repository setting is the real protection.

Every workflow takes a `runs-on` input. It is a JSON array of runner labels and must start with `self-hosted`. The defaults use the size labels `small`, `medium` and `large` beside `linux`, and `dedicated` asks for the widest machine on offer. Write it as a quoted string:

```yaml
with:
  runs-on: '["self-hosted", "linux", "large"]'
```

The runners need git, rustup, Docker with Buildx, `musl-gcc` (Debian's `musl-tools`), `sha256sum`, `ldd` and the GitHub CLI. Node and uv are installed per job at the versions you ask for.

A called workflow can only use the permissions its caller grants, so each example below lists the `permissions` that job needs. The top of your caller should still be `permissions: contents: read`.

Third-party actions inside these workflows are pinned to full commit SHAs.

## Releases and assets

A release happens in two stages. `semantic-release.yml` works out the version, tags it and publishes the GitHub release with semantic-release's own GitHub plugin. Jobs after it build from that tag and attach their output: `rust-musl-release.yml` uploads the binary and checksum to the release, and `container-image.yml` builds an image from the same binary.

The other way is to build inside the release job, from an `@semantic-release/exec` `prepareCmd`, and list the files under the GitHub plugin's `assets`. That makes the release all or nothing. But the one job then needs Rust, musl, Node and Docker together, nothing runs in parallel, and none of it can be shared between repositories. The cost of the two-stage design is a gap of a few minutes in which the release exists without its binary. If a later job fails, the tag and release stay and you re-run the failed job. If you need the all-or-nothing behaviour, `semantic-release.yml` still supports it through `extra-plugins` and `pre-command`.

Turn off the GitHub plugin's issue and pull request comments. The release job is only given `contents: write`, so commenting would fail after the release is out:

```json
["@semantic-release/github", {
  "successComment": false,
  "failComment": false,
  "labels": false,
  "releasedLabels": false
}]
```

This repository has no CHANGELOG. Its release notes are on the GitHub releases page.

## rust-ci.yml

Runs `cargo fmt --all --check`, `cargo clippy --locked --workspace --all-targets -- -D warnings` and `cargo test --locked --workspace`, with the cargo registry and target directory cached by Swatinem/rust-cache. The cache is only saved from the default branch.

```yaml
jobs:
  rust:
    uses: sam-ruff/actions/.github/workflows/rust-ci.yml@v1
    with:
      toolchain: 1.98.0
      env: |
        DATABASE_REQUIRED=1
      post-command: cargo run --locked -q -- openapi | diff -u web/openapi.json -
```

| Input | Default | |
|---|---|---|
| `runs-on` | `["self-hosted", "linux", "medium"]` | |
| `working-directory` | `.` | |
| `toolchain` | `stable` | Empty uses `rust-toolchain.toml` |
| `fmt`, `clippy`, `test` | `true` | Turn a step off |
| `locked` | `true` | |
| `clippy-args` | `--workspace --all-targets` | Before the `--` |
| `test-args` | `--workspace` | |
| `env` | | `KEY=VALUE` lines for every later step |
| `pre-command` | | Runs after the toolchain is installed |
| `post-command` | | Runs after the tests |
| `submodules` | `false` | `true` or `recursive` |
| `cache` | `true` | |
| `timeout-minutes` | `45` | |
| `allow-fork-pull-requests` | `false` | |

No secrets or outputs.

## node-ci.yml

Runs `npm ci` in a web subdirectory, then whichever of the named npm scripts you leave set. An empty script name skips that step. Set `e2e-script` to install Playwright browsers and run the end-to-end tests.

`check-generated` runs after `npm ci` and should regenerate files that are committed, such as API types built from an OpenAPI document. The job fails if the checkout has any change or untracked file afterwards, so `node_modules` must be in `.gitignore`.

```yaml
jobs:
  web:
    uses: sam-ruff/actions/.github/workflows/node-ci.yml@v1
    with:
      working-directory: web
      check-generated: npm run gen:api
      e2e-script: e2e
```

| Input | Default | |
|---|---|---|
| `runs-on` | `["self-hosted", "linux", "medium"]` | |
| `working-directory` | `web` | Holds `package-lock.json` |
| `node-version` | `24.17.0` | |
| `env` | | `KEY=VALUE` lines |
| `pre-command` | | Runs before `npm ci` |
| `check-generated` | | Regenerates committed files |
| `typecheck-script` | `typecheck` | |
| `lint-script` | `lint` | |
| `test-script` | `test` | |
| `build-script` | `build` | |
| `e2e-script` | | |
| `playwright-browsers` | `chromium` | |
| `playwright-with-deps` | `false` | Needs passwordless sudo |
| `timeout-minutes` | `30` | |
| `allow-fork-pull-requests` | `false` | |

No secrets or outputs.

## semantic-release.yml

Runs semantic-release with your repository's config file. If the `package.json` in `working-directory` lists `semantic-release`, the workflow runs `npm ci` and uses your pinned versions. Otherwise it installs `semantic-release@25.0.9` plus anything in `extra-plugins` into a temporary directory. Version 25 already bundles the commit analyser, release notes generator and GitHub plugins.

```yaml
jobs:
  release:
    needs: [rust, web]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: sam-ruff/actions/.github/workflows/semantic-release.yml@v1
    permissions:
      contents: write
```

| Input | Default | |
|---|---|---|
| `runs-on` | `["self-hosted", "linux", "small"]` | |
| `working-directory` | `.` | |
| `node-version` | `24.17.0` | |
| `semantic-release-version` | `25.0.9` | |
| `extra-plugins` | | Space-separated npm specs |
| `pre-command` | | Runs before semantic-release |
| `dry-run` | `false` | |
| `timeout-minutes` | `20` | |

The optional secret `RELEASE_TOKEN` replaces `GITHUB_TOKEN`, for example when `@semantic-release/git` has to push past branch protection.

| Output | |
|---|---|
| `new-release-published` | `"true"` or `"false"` |
| `version` | `1.4.0` |
| `tag` | `v1.4.0` |

## rust-musl-release.yml

Builds a static `x86_64-unknown-linux-musl` binary with `musl-gcc` as the C compiler, checks with `ldd` that it has no dynamic dependencies, and writes a `.sha256` file beside it. Both go into a workflow artifact for later jobs. When `tag` is set, the workflow checks out that tag and attaches both files to its release with `gh release upload --clobber`, so re-running it replaces the assets.

Use rustls rather than OpenSSL. Debian's musl toolchain has no OpenSSL to link against, and the build will fail.

```yaml
jobs:
  binary:
    needs: release
    if: needs.release.outputs.new-release-published == 'true'
    uses: sam-ruff/actions/.github/workflows/rust-musl-release.yml@v1
    permissions:
      contents: write
    with:
      package: myapp
      tag: ${{ needs.release.outputs.tag }}
```

| Input | Default | |
|---|---|---|
| `runs-on` | `["self-hosted", "linux", "large"]` | |
| `package` | required | Cargo package |
| `binary` | the package name | |
| `tag` | | Release to attach to. Empty only builds |
| `asset-name` | `BINARY-linux-amd64` | |
| `asset-label` | | Label on the release page |
| `artifact-name` | `musl-binary` | |
| `working-directory` | `.` | |
| `toolchain` | `stable` | Empty uses `rust-toolchain.toml` |
| `cargo-args` | | Such as `--features embed-ui` |
| `env` | | `KEY=VALUE` lines |
| `node-version` | | Sets up Node for the pre-build command |
| `pre-build-command` | | `RELEASE_VERSION` is set, without the `v` |
| `verify-command` | | `BINARY` is the built binary's path |
| `cache` | `true` | |
| `timeout-minutes` | `60` | |
| `allow-fork-pull-requests` | `false` | |

Outputs are `asset-name`, `artifact-name` and `sha256`. The job needs `contents: write` from its caller even when `tag` is empty, because GitHub checks a called workflow's permissions before it runs.

## container-image.yml

Builds with Buildx and pushes to GHCR by default, logging in with the workflow actor and `GITHUB_TOKEN`. With `version: 1.4.0` the image is tagged `1.4.0`, `1.4` and `latest`, plus `sha-` and the short commit hash. OCI labels come from docker/metadata-action, and provenance attestations are on (`mode=max`). `VERSION` and `GIT_SHA` are passed as build arguments.

`binary-artifact` downloads a workflow artifact, such as the musl binary, into `binary-artifact-path` before the build, so the Dockerfile only has to copy it in:

```dockerfile
FROM scratch
COPY --chmod=0755 dist/myapp-linux-amd64 /myapp
USER 65532:65532
ENTRYPOINT ["/myapp"]
```

A `scratch` image has no CA certificates, `/etc/passwd` or `/tmp`. A binary that loads the system's root certificates, or needs a writable directory, is better off on a static distroless base such as `cgr.dev/chainguard/static`.

```yaml
jobs:
  image:
    needs: [release, binary]
    uses: sam-ruff/actions/.github/workflows/container-image.yml@v1
    permissions:
      contents: read
      packages: write
    with:
      ref: ${{ needs.release.outputs.tag }}
      version: ${{ needs.release.outputs.version }}
      binary-artifact: ${{ needs.binary.outputs.artifact-name }}
```

| Input | Default | |
|---|---|---|
| `runs-on` | `["self-hosted", "linux", "small"]` | |
| `registry` | `ghcr.io` | |
| `image` | the repository, lowercased | Without the registry |
| `version` | | Empty tags only `sha-SHORTSHA` |
| `latest` | `true` | |
| `extra-tags` | | metadata-action tag rules, one per line |
| `ref` | the triggering commit | |
| `context` | `.` | |
| `dockerfile` | `Dockerfile` | From the repository root |
| `platforms` | `linux/amd64` | |
| `build-args` | | `KEY=VALUE` lines |
| `binary-artifact` | | |
| `binary-artifact-path` | `dist` | |
| `push` | `true` | |
| `cache` | `false` | Buildx layer cache in the Actions cache |
| `timeout-minutes` | `30` | |
| `allow-fork-pull-requests` | `false` | |

For another registry, pass `registry` and the secrets `REGISTRY_USERNAME` and `REGISTRY_PASSWORD`. Outputs are `image`, `digest` and `tags`.

## docs-pages.yml

Installs a pinned Zensical with uv, runs `zensical build --clean`, and deploys the site to GitHub Pages with `actions/upload-pages-artifact` and `actions/deploy-pages`. Set the Pages source to "GitHub Actions" under Settings, Pages first. The `github-pages` environment only accepts deployments from the default branch unless you change its rules.

```yaml
jobs:
  docs:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: sam-ruff/actions/.github/workflows/docs-pages.yml@v1
    permissions:
      contents: read
      pages: write
      id-token: write
```

| Input | Default | |
|---|---|---|
| `runs-on` | `["self-hosted", "linux", "small"]` | |
| `working-directory` | `.` | Holds `zensical.toml` |
| `config-file` | | Passed to `--config-file` |
| `site-dir` | `site` | |
| `zensical-version` | `0.0.71` | |
| `uv-version` | `0.13.1` | |
| `python-version` | `3.13` | |
| `strict` | `false` | Fail on warnings |
| `pre-command` | | |
| `deploy` | `true` | Off only builds |
| `timeout-minutes` | `20` | |
| `allow-fork-pull-requests` | `false` | |

The output `page-url` is the deployed site's address.

## A complete caller

A Rust service that embeds a web UI, released as a static binary and a GHCR image, with its docs on Pages:

```yaml
name: CI and release

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: false

jobs:
  rust:
    uses: sam-ruff/actions/.github/workflows/rust-ci.yml@v1
    with:
      toolchain: 1.98.0

  web:
    uses: sam-ruff/actions/.github/workflows/node-ci.yml@v1
    with:
      working-directory: web
      check-generated: npm run gen:api
      e2e-script: e2e

  release:
    needs: [rust, web]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: sam-ruff/actions/.github/workflows/semantic-release.yml@v1
    permissions:
      contents: write

  binary:
    needs: release
    if: needs.release.outputs.new-release-published == 'true'
    uses: sam-ruff/actions/.github/workflows/rust-musl-release.yml@v1
    permissions:
      contents: write
    with:
      package: myapp
      tag: ${{ needs.release.outputs.tag }}
      toolchain: 1.98.0
      node-version: 24.17.0
      pre-build-command: cd web && npm ci --no-audit --no-fund && npm run build

  image:
    needs: [release, binary]
    uses: sam-ruff/actions/.github/workflows/container-image.yml@v1
    permissions:
      contents: read
      packages: write
    with:
      ref: ${{ needs.release.outputs.tag }}
      version: ${{ needs.release.outputs.version }}
      binary-artifact: ${{ needs.binary.outputs.artifact-name }}

  docs:
    needs: [rust, web]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: sam-ruff/actions/.github/workflows/docs-pages.yml@v1
    permissions:
      contents: read
      pages: write
      id-token: write
```

## Working on this repository

Run `scripts/install-hooks.sh` once after cloning. The pre-commit hook runs actionlint through `scripts/actionlint.sh`, which downloads a checksum-pinned copy. CI runs actionlint and calls each workflow against the small projects in `tests/fixtures`. A push to `main` with a `feat` or `fix` commit releases a new version and moves the major tag.
