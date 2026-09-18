# Deploy Periodic Agent

`deploy-periodic-agent` is workspace tooling — a skill in this repo
(`.claude/skills/deploy-periodic-agent/`) that onboards any workspace skill
(`.claude/skills/<name>`) to run **on a schedule as an agentic Prow periodic
job** in `openshift/release`. The periodic runs the Claude Code CLI with the
chosen skill loaded as its system prompt, and nothing else.

It reuses the existing Distributed-Tracing QE agent machinery
(`openshift-observability-qe-agent`) — runner image, Google Vertex AI backend,
and credentials — via a new, **de-gated** shared agent step that runs
unconditionally (the qe-agent only fires after a test failure) and fetches the
skill from this repo's raw URL by name.

The entire capability is **[PLANNED: TRACING-6824]**. This is internal
workspace/CI tooling, not a customer-facing product feature, so the GA/TP
support levels do not apply.

## Scope

**In scope:**
- One-time onboarding of `rhobs/redhat-build-of-opentelemetry-workspace` into
  `openshift/release`, plus one shared, generalized agent step.
- Recurring per-skill onboarding: generate a periodic job per skill to run on a
  user-chosen cadence.
- A placeholder target skill, `rhosdt-release-notes-audit`, as the first
  onboarding subject.

**Out of scope:**
- Making the placeholder skill functional (it is a stub).
- A per-skill step-registry ref, or reusing the failure-gated qe-agent step
  unchanged.
- Solving GitLab and VPN/internal-network access (documented as follow-ups).

## Behavioral Rules

### Phases

1. **[PLANNED: TRACING-6824]**: The tooling has two phases with different
   frequencies: a **one-time setup** (done once, ever) and a **recurring
   per-skill onboarding**. The skill is primarily about the recurring
   onboarding; it performs the one-time setup only when it detects the setup is
   missing, then never again.

2. **[PLANNED: TRACING-6824]**: One-time setup onboards this repo into
   `openshift/release` (base `ci-operator/config/rhobs/redhat-build-of-opentelemetry-workspace/…`)
   and creates **one** shared agent step,
   `openshift-observability-skill-agent`, under
   `ci-operator/step-registry/openshift-observability/skill-agent/`.

### Shared agent step

3. **[PLANNED: TRACING-6824]**: The shared step is **de-gated** — it runs Claude
   unconditionally, with no `has_test_failures` check. One step serves every
   skill, parameterized by the `AGENT_SKILL` environment variable.

4. **[PLANNED: TRACING-6824]**: The step **fetches `SKILL.md` at runtime** from
   this repo's raw URL
   (`https://raw.githubusercontent.com/rhobs/redhat-build-of-opentelemetry-workspace/main/.claude/skills/$AGENT_SKILL/SKILL.md`).
   Skills are the single source of truth in this repo and are **not vendored**
   into `openshift/release`.

5. **[PLANNED: TRACING-6824]**: The step reuses the qe-agent's runner image,
   Vertex AI configuration, and credentials: `ci-claude-code` (Vertex service
   account) and `distributed-tracing` (Jira secrets).

### Per-skill onboarding

6. **[PLANNED: TRACING-6824]**: Onboarding a skill generates a periodic `test:`
   entry that runs **only** the shared agent step (no cluster profile by
   default, no test suite), with `AGENT_SKILL` set to the skill name and a
   user-chosen `cron`. The deployed skill is schedule-agnostic; the cadence is
   chosen at onboarding time.

7. **[PLANNED: TRACING-6824]**: The skill name must match `^[A-Za-z0-9_-]+$` and
   correspond to an existing `.claude/skills/<name>/SKILL.md` in this repo.

8. **[PLANNED: TRACING-6824]**: After editing `ci-operator/config/**`, the
   generated Prow jobs are produced with `make update` and validated with
   `make checkconfig`; `ci-operator/jobs/**` is never hand-edited. Errors stop
   the flow and are surfaced verbatim.

### Delivery

9. **[PLANNED: TRACING-6824]**: Changes are delivered as a fork-based PR to
   `openshift/release`, testable pre-merge via a `/pj-rehearse <job-name>` PR
   comment, and require human/OWNERS review and merge — skills are fetched from
   `main` at runtime, so the job works only once merged.

## Constraints

- **Credential gaps (follow-ups, required by the placeholder skill):** reading
  or writing a GitLab release object needs a **GitLab token** not in the
  qe-agent credential set; reaching internal services such as
  `gitlab.cee.redhat.com` needs **VPN / Red Hat internal-network access** not
  available to a default Prow job. Both must be resolved before the placeholder
  skill can function.
- **Placeholder skill:** `rhosdt-release-notes-audit` is a stub, clearly marked
  as not yet implemented. Its intended future behavior: for a given RHOSDT
  release, check the associated Jira features/bugs, verify release notes exist on
  the corresponding GitLab release object, and move tickets back to *In
  Progress* if they do not.

## Cross-Reference

- Detailed design and rationale:
  `docs/superpowers/specs/2026-09-18-deploy-periodic-agent-design.md`.
- Tracking: **TRACING-6824** (sub-task of **TRACING-6383** — "How to automate
  release notes?").
