---
name: onboard-component
description: >
  Onboard or deprecate a collector component (receiver, processor, exporter,
  connector, extension) in the Red Hat build of OpenTelemetry. Takes a Jira
  Epic as input, gathers context, verifies upstream stability, and drives
  the cross-repo changes: manifest, docs, spec, PRs, and Jira updates.
argument-hint: "TRACING-1234"
---

# Onboard a Collector Component

Add or deprecate a receiver, processor, exporter, connector, or extension
in the Red Hat build of OpenTelemetry. This is a cross-repo procedure
spanning multiple repositories.

## Usage

```
/onboard-component TRACING-1234
```

The Jira Epic key is required. If no argument is provided, ask the user
for the Epic key before proceeding.

## Workflow

### Step 1: Gather Context from Jira

Use the `/jira:jira` skill to fetch the Epic and its child stories. Extract:
- Component name and type (receiver, processor, exporter, connector, extension)
- Target support level (TP or GA)
- Any existing PRs linked in the issues
- Blockers or decisions noted in issue comments

Review all child stories under the Epic. Identify which steps have already
been completed (e.g. manifest.yaml PR already merged) and which are blocked.

### Step 2: Verify Upstream Stability

Check the component's `metadata.yaml` or `README.md` in
`opentelemetry-collector-contrib` (or core) for its stability level per
signal type.

- **For TP onboarding:** the component must be at **beta** stability or
  higher upstream. If it is alpha, stop and flag this to the user.
- **For GA promotion:** the component must have been shipped as TP for at
  least one release. Check `.ai/spec/what/collector.md` to confirm it is
  already listed as TP.

Identify the exact Go module path from the upstream repo (e.g.
`github.com/open-telemetry/opentelemetry-collector-contrib/receiver/webhookeventreceiver`).

### Step 3: Present the Plan

Before doing any work, present the user with a summary:
- Which repos will be touched
- What PRs will be opened (with Jira links)
- What is already done (from Step 1)
- What is blocked or needs a decision

Wait for user approval before proceeding.

### Step 4: Make Changes

Each target repo has its own `AGENTS.md` with build and test instructions.
Read the target repo's `AGENTS.md` before making changes there.

#### a) `redhat-opentelemetry-collector`

Add the component's gomod entry to `manifest.yaml` in the appropriate
section (`receivers`, `exporters`, `processors`, `connectors`, `extensions`).
The version must match the pinned collector version in `manifest.yaml` →
`dist.version`.

Build and verify per the repo's `AGENTS.md`. The generated `_build/` source
must be committed — it is required for Konflux hermetic builds.

Update the changelog noting the new component and its support level.

#### b) `openshift-docs` (branch `standalone-otel-docs-main`)

A component is not supported until it is documented. Two files are needed:

**Module file** in `modules/` — naming convention:
`otel-<type>-<name>-<type-singular>.adoc` (e.g. `otel-receivers-kafka-receiver.adoc`).

**Assembly include** in `otel-collector/otel-collector-<type>.adoc` — add
an `include::` directive for the new module in alphabetical order.

#### c) Workspace (this repo)

Add the component to the appropriate table in `.ai/spec/what/collector.md`
with the correct support level.

### Step 5: Open PRs

Open PRs in each repo. Every PR **must** link the Jira Epic and relevant
Story in the description.

PR title format: `TRACING-XXXX: <summary>`

### Step 6: Update Jira

After PRs are opened:
- Link each PR to its corresponding Jira Story
- Transition completed Stories
- Add a comment on the Epic summarizing progress

## Deprecating a Component

Reverse the onboarding steps:

1. Remove from `manifest.yaml`, rebuild per the repo's `AGENTS.md`
2. Remove the doc module and its assembly include from `openshift-docs`
3. Update the collector spec table in `.ai/spec/what/collector.md`
4. Note removed components in the release notes and update the changelog
5. Update Jira accordingly

For a reference deprecation PR, see:
https://github.com/os-observability/konflux-opentelemetry/pull/1002

## Checklist

- [ ] Upstream stability verified (beta+ for TP, TP for one release for GA)
- [ ] `manifest.yaml` entry added/removed with correct version
- [ ] `_build/` regenerated and committed
- [ ] Build passes (per repo's `AGENTS.md`)
- [ ] Changelog updated
- [ ] Component row added/updated in `.ai/spec/what/collector.md`
- [ ] AsciiDoc module created/removed in `openshift-docs/modules/`
- [ ] Assembly file updated with `include::` directive
- [ ] All PRs link Jira Epic and Story
- [ ] Jira Stories transitioned and updated
