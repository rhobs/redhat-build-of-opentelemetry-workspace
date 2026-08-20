# Onboarding a Collector Component

Step-by-step procedure for adding a new receiver, processor, exporter, connector, or extension to the Red Hat build of OpenTelemetry. This is a cross-repo operation spanning three repositories.

## Agent Workflow

### Phase 1: Gather Context

1. **Find the Epic.** Ask the user for the TRACING Epic that tracks the onboarding. Use the `/jira:jira` skill to fetch the Epic and its child stories. Extract:
   - Component name and type (receiver, processor, exporter, connector, extension)
   - Target support level (TP or GA)
   - Any existing PRs linked in the issues
   - Blockers or decisions noted in issue comments
2. **Check Jira state.** Review all child stories under the Epic. Identify which steps have already been completed (e.g. manifest.yaml PR already merged) and which are blocked. Report the current state to the user before proceeding.

### Phase 2: Research the Component

3. **Verify upstream stability.** Check the component's `metadata.yaml` or `README.md` in `opentelemetry-collector-contrib` (or core) for its stability level per signal type.
   - **For TP onboarding:** the component must be at **beta** stability or higher upstream. If it is alpha, stop and flag this to the user — alpha components cannot be onboarded as TP.
   - **For GA promotion:** the component must have been shipped as TP for at least one release. Check `what/collector.md` to confirm it is already listed as TP.
4. **Identify the gomod path.** Determine the exact Go module path from the upstream repo (e.g. `github.com/open-telemetry/opentelemetry-collector-contrib/receiver/webhookeventreceiver`).

### Phase 3: Present the Plan

5. **List all PRs and actions.** Before doing any work, present the user with a summary:
   - Which repos will be touched
   - What PRs will be opened (with Jira links)
   - What is already done (from Phase 1)
   - What is blocked or needs a decision
   
   Wait for user approval before proceeding.

## Prerequisites

- The component exists upstream in `opentelemetry-collector` (core) or `opentelemetry-collector-contrib`.
- A Jira Epic (TRACING-XXXX) exists to track the onboarding work.
- Upstream stability is beta or higher (for TP) or the component has shipped as TP for at least one release (for GA).

## Steps

### 1. Add to manifest.yaml

**Repo:** `redhat-opentelemetry-collector`

Add the component's gomod entry to the appropriate section in `manifest.yaml`:

```yaml
receivers:
  - gomod: github.com/open-telemetry/opentelemetry-collector-contrib/receiver/<name>receiver v0.X.0
```

Sections: `receivers`, `exporters`, `processors`, `connectors`, `extensions`. The gomod path follows the upstream module layout. The version must match the pinned collector version in `manifest.yaml` → `dist.version`.

### 2. Regenerate _build/

**Repo:** `redhat-opentelemetry-collector`

```bash
make generate
```

This runs OCB against the updated `manifest.yaml` and regenerates `_build/main.go` and `_build/components.go`. The generated source is committed — it must be checked in for Konflux hermetic builds to work.

### 3. Verify the build

**Repo:** `redhat-opentelemetry-collector`

```bash
make build
make test
```

Both must pass. If the build fails, diagnose and fix before proceeding — do not open a PR with a broken build.

### 4. Update the changelog

**Repo:** `redhat-opentelemetry-collector`

Add an entry to the changelog noting the new component and its support level.

### 5. Update the collector spec

**Repo:** workspace (this repo)

Add the new component to the appropriate table in `.ai/spec/what/collector.md` with the correct support level:

```markdown
| <Name> | **TP** | Added in <version>. <upstream stability note>. |
```

### 6. Add documentation

**Repo:** `openshift-docs` (branch `standalone-otel-docs-main`)

A component is not supported until it is documented. Two files are needed:

**a) Module file** in `modules/`:

Naming convention: `otel-<type>-<name>-<type-singular>.adoc`

Examples:
- `otel-receivers-kafka-receiver.adoc`
- `otel-exporters-debug-exporter.adoc`
- `otel-processors-filter-processor.adoc`
- `otel-connectors-count-connector.adoc`
- `otel-extensions-filestorage-extension.adoc`

The module documents the component's configuration options, supported signals, and an example configuration snippet.

**b) Assembly include** in the appropriate `otel-collector/otel-collector-<type>.adoc`:

Add an `include::` directive for the new module, following alphabetical order within the existing includes.

### 7. Open PRs

Open PRs in this order (each can proceed independently). Every PR **must** link the Jira Epic and relevant Story in the PR description:

1. `redhat-opentelemetry-collector` — manifest.yaml + `_build/` + changelog
2. `openshift-docs` — documentation module + assembly include
3. Workspace — spec update in `what/collector.md`

PR title format: `TRACING-XXXX: <summary>`

PR description must include:
- Link to the Jira Epic
- Link to the specific Story being addressed
- Summary of what was changed and why

### 8. Update Jira

After PRs are opened:
- Link each PR to its corresponding Jira Story
- Transition completed Stories (e.g. move to "In Review" or "Done")
- Add a comment on the Epic summarizing progress

## Checklist

- [ ] Upstream stability verified (beta+ for TP, TP for one release for GA)
- [ ] `manifest.yaml` entry added with correct version
- [ ] `_build/` regenerated and committed
- [ ] `make build` passes
- [ ] `make test` passes
- [ ] Changelog updated
- [ ] Component row added to `what/collector.md` with support level
- [ ] AsciiDoc module created in `openshift-docs/modules/`
- [ ] Assembly file updated with `include::` directive
- [ ] All PRs link Jira Epic and Story
- [ ] Jira Stories transitioned and updated

## Removing a Component

Reverse the steps above: remove from `manifest.yaml`, regenerate `_build/`, remove the doc module and its include, update the collector spec table. Note removed components in the release notes and update the changelog.
