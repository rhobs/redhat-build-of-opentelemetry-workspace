# Red Hat build of OpenTelemetry Workspace

Cross-repo workspace for Red Hat build of OpenTelemetry — shared specs, routing, and AI conventions.

## Repositories

| Repo                                                                                                 | Purpose                                                               |
|------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------|
| [opentelemetry-collector](https://github.com/open-telemetry/opentelemetry-collector)                 | Core collector                                                        |
| [opentelemetry-collector-contrib](https://github.com/open-telemetry/opentelemetry-collector-contrib) | Collector contrib with all components                                 |
| [redhat-opentelemetry-collector](https://github.com/os-observability/redhat-opentelemetry-collector) | Red Hat distribution of the collector                                 |
| [opentelemetry-operator](https://github.com/open-telemetry/opentelemetry-operator)                   | Kubernetes operator                                                   |
| [konflux-opentelemetry](https://github.com/os-observability/konflux-opentelemetry)                   | Downstream productization repository, contains all product components |
| [openshift-docs](https://github.com/openshift/openshift-docs/tree/standalone-otel-docs-main)         | Documentation for the Red Hat build of OpenTelemetry                  |
| [distributed-tracing-console-plugin](https://github.com/openshift/distributed-tracing-console-plugin) | OpenShift console plugin for distributed tracing                      |
| [logging-view-plugin](https://github.com/openshift/logging-view-plugin)                              | OpenShift console plugin for logging view                             |
| [multicluster-observability-addon](https://github.com/stolostron/multicluster-observability-addon)   | Multi-cluster observability addon for ACM, includes OpenTelemetry     |
| [distributed-tracing-qe](https://github.com/openshift/distributed-tracing-qe)                        | Additional product test in tests/e2e-otel                             |
| [release](https://github.com/openshift/release) | OpenShift CI jobs for stage and downstream in ci-operator/config/openshift/open-telemetry-opentelemetry-operator           |

## Setup

Clone all repos into this directory:

```bash
make clone-repos
```

Pull latest changes in all repos:

```bash
make pull-repos
```

## Specs

All specifications live in `.ai/spec/`. Start with [`.ai/spec/README.md`](.ai/spec/README.md) for the product overview and reading guide. Use [`.ai/spec/how/repo-map.md`](.ai/spec/how/repo-map.md) to find which repo and spec file to update for a given concern.

1. Create spec: a new spec files should be created with `/superpowers:brainstorming` [skill](https://github.com/obra/superpowers/tree/main).
   ```
   > /superpowers:brainstorming create or update specs for https://redhat.atlassian.net/browse/TRACING-6499. Also consider https://redhat.atlassian.net/browse/OBSDA-1454 which is the parent
   ticket. Do not commit and do not proceed with implementation.
   ```
   As an input use product requirements or design ideas. The output should be a set of spec files in `.ai/spec/`.
1. Create Jira tickets: in the same session run `/make-jira-from-spec` skill to create Jira tickets from the spec files.
1. Implementation: use `/superpowers:brainstorming` skill with the Jira ticket as an input. After the implementation is done ask agent to update the spec files based on the implementation. 

### Create initial spec files

The `/spec-first:init` [skill](https://github.com/joshuawilson/spec-first) was used to create initial set of spec files. To install the `spec-first` plugin, run:
```bash
/plugin marketplace add joshuawilson/spec-first
/plugin install spec-first@spec-first-marketplace
```

Example prompt: 
> /spec-first:init create the specs. Document which features are supported and which not. The supported features are the ones that are documented in the docs. These features are either generally available (GA) or tech-preview (TP). If a feature is in the source code, but missing in docs, it is
not supported.

## Regression Detection

Automated system that detects upstream regressions in OpenTelemetry repos compared to the currently shipped Red Hat build of OpenTelemetry release. It dynamically discovers components from `konflux-opentelemetry` (manifest.yaml, submodule pins, release branch) — no manual config updates are needed for new releases.

### What it detects

| Method | What it finds |
|--------|---------------|
| Changelog analysis | Breaking changes, deprecations, behavior changes in CHANGELOG.md |
| Code diff analysis | Removed/renamed config fields, changed defaults, new required fields |
| Feature gate tracking | Gates promoted Alpha→Beta→Stable→Removed that change defaults |
| GitHub issue/PR scanning | Bugs, regressions, reverted PRs via `gh` CLI |
| Doc validation | Stale docs (field removed upstream), undocumented new fields |
| Test coverage matrix | Per-component coverage report (dedicated/implicit/none) |
| Dependency tracking | Significant version bumps in go.mod |

### Run locally

Before running locally, check the latest [CI run](../../actions/workflows/regression-detection.yml) — if the report is recent enough, download the artifact instead to save tokens.

```bash
# Using Claude Code skill (interactive)
/otel-regression-detection

# Full regression detection
make regression-detection

# Single detection method (faster, lower cost)
make regression-detection METHOD=changelog
```

### Run in CI

The GitHub Actions workflow (`.github/workflows/regression-detection.yml`) checks weekly for new upstream operator releases and runs automatically when a new release is detected. It can also be triggered manually via the **Run workflow** button on the [Actions page](../../actions/workflows/regression-detection.yml).

### Cost controls

- **Budget cap**: $25 per run (enforced via `--max-budget-usd 25`)
- **CI schedule**: runs only when a new upstream release is detected (checked weekly)
- **Single-method runs**: use `--method <name>` for targeted, lower-cost checks
- **Check CI first**: download the latest CI artifact before running locally

### Output

Reports are written to `reports/`:
- `regression-report-YYYY-MM-DD.md` — full markdown report with findings by severity
- `regression-summary-YYYY-MM-DD.json` — machine-readable summary counts

### How it stays current

Everything is derived at runtime from `konflux-opentelemetry`:

| What | Source |
|------|--------|
| Component list | `redhat-opentelemetry-collector/manifest.yaml` |
| Collector base version | `manifest.yaml` → `dist.version` |
| Operator base commit | `git submodule status` |
| Release branch | `.gitmodules` |
| Downstream version | `bundle-patch/patch_csv.yaml` |
| Doc coverage | Glob `openshift-docs/otel-collector/modules/*.adoc` |

When `konflux-opentelemetry` is updated for a new release, regression detection automatically picks up the changes.

## Conventions

- **Jira**: Project key `TRACING` on `redhat.atlassian.net`
- **Git workflow**: Fork-based — push to your fork, PR against `origin/main`, squash before pushing
- **Per-repo guides**: Each repo has an `AGENTS.md` with repo-specific conventions
