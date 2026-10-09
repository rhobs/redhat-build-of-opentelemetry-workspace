---
name: otel-sast-triage
description: >
  Triage SAST (Static Application Security Testing) reports for Red Hat build
  of OpenTelemetry releases. Parses Snyk SARIF findings from Konflux pipeline
  output, filters noise (test code, examples, build tooling),
  diffs against a baseline release, and surfaces only findings that need
  human review. Use during release testing when SAST reports are available.
argument-hint: "3.11.0 [--baseline 3.10.2] [--product otel|tempo]"
---

# SAST Triage Skill

Automate triage of Konflux SAST reports for RHOSDT releases. Reduces ~100+ raw
findings down to the 2-5 that actually need human eyes.

## When to Use This Skill

Use this skill when:
- A new RHOSDT release has SAST reports to review
- You need to triage Snyk SARIF findings from Konflux pipeline output
- A release testing epic includes a SAST analysis task
- You want to compare SAST findings between two releases

## Usage

```
/otel-sast-triage 3.11.0
/otel-sast-triage 3.11.0 --baseline 3.10.2
/otel-sast-triage 3.11.0 --baseline 3.10.2 --product tempo
```

## Arguments

- **Version** (positional, required) — release version to triage (e.g. `3.11.0`)
- **`--baseline`** — previous release version for cross-release diff. If omitted, look for the most recent prior version directory in `konflux/sast-report/`.
- **`--product`** — `otel` (default) or `tempo`

## Prerequisites

SARIF reports must already exist in `konflux/sast-report/`. These are generated
by the `snapshot-security-analyzer` tool against a Konflux snapshot. If the
directory for the requested version doesn't exist, tell the user to run
`snapshot-security-analyzer` first.

## Workflow

### Step 1: Locate and load SARIF files

Find the report directory matching the version and product:

```bash
ls konflux/sast-report/ | grep -i "${VERSION}.*${PRODUCT}"
```

The directory naming convention is `<version>-<product>-main/` (e.g.
`3.11.0-otel-main/`). Inside, each component image has its own subdirectory
under `attachments/`.

**Deduplication:** All component images (bundle, collector, operator,
target-allocator) scan the same source repo and produce identical SARIF.
Pick **one** component's `sast_snyk_check_out.sarif` — note this in the
report header. Do NOT process all four.

```bash
# Find the first Snyk SARIF
SARIF=$(find "konflux/sast-report/${DIR}/attachments" -name "sast_snyk_check_out.sarif" | head -1)
```

Also check for other SARIF scanners:
- `sast_unicode_check_out.sarif` — usually 0 findings, note if non-zero
- `shellcheck-results.sarif` — usually 2 stable findings in test scripts
- `coverity-results.sarif` — if present, process separately (higher precision)

### Step 2: Parse findings

Extract each finding from the SARIF JSON:

```bash
jq '[.runs[0].results[] | {
  ruleId,
  level,
  message: .message.text,
  uri: .locations[0].physicalLocation.artifactLocation.uri,
  startLine: .locations[0].physicalLocation.region.startLine,
  fingerprint: .fingerprints["csdiff/v0"]
}]' "$SARIF"
```

Record the total count.

### Step 3: Classify each finding

Apply these filters **in order**. A finding matching any filter is classified
as noise. Track which filter caught it for the summary.

#### Filter 1: Snyk test-flagged
The rule ID contains `/test]` — Snyk itself determined this is test code.

```
ruleId matches: /test]$
```

#### Filter 2: Test file paths
The file path indicates test code.

```
uri matches any of:
  _test.go$
  /test/
  /tests/
  /testdata/
  /testutil/
  /testing/
  /e2e/
  /e2e-/
  testenv
  mock
```

#### Filter 3: Example/demo code
Example applications are not shipped in the product image.

```
uri matches any of:
  /examples/
  /example/
  /demo/
  store-demo
  /sample/
```

#### Filter 4: Build tooling
Scripts and tools used only during CI/build, not present in the shipped image.

```
uri matches any of:
  scripts/
  tools/
  cmd/check-
  cmd/config-docs
  cmd/obi-
  cmd/generate-
  ci-analysis/
  snapshot-tool
```

#### Filter 5: Coverity test YAML (if Coverity SARIF present)
Coverity SIGMA rules flagging Kubernetes manifests in test fixtures.

```
uri matches: /tests/e2e  AND  ruleId contains: SIGMA
```

### Step 4: Cross-release diff (if baseline available)

If `--baseline` is provided (or auto-detected):

1. Load the baseline SARIF the same way (Step 1-2)
2. Extract `csdiff/v0` fingerprints from the baseline
3. Compare against the current release fingerprints
4. Flag findings as **new** (not in baseline) or **existing** (in baseline)

```bash
# Extract baseline fingerprints
BASELINE_SARIF=$(find "konflux/sast-report/${BASELINE_DIR}/attachments" -name "sast_snyk_check_out.sarif" | head -1)
jq -r '[.runs[0].results[].fingerprints["csdiff/v0"]]' "$BASELINE_SARIF" > /tmp/baseline_fps.json
```

New findings that also survived the noise filters deserve the most attention.

### Step 5: Assess surviving findings

For each finding that passed ALL noise filters (i.e. classified as
potentially real):

1. **Read the source code** at the flagged location to understand context
2. **Check severity** — `warning` level findings are higher priority than `note`
3. **Assess reachability** — is this code in a shipped binary? Is the
   vulnerable pattern actually exploitable in context?
4. **Write a one-paragraph assessment** — what the finding is, why it
   survived filtering, and your preliminary judgment (likely real / likely
   noise with explanation)

Group the assessments by severity: warnings first, then notes.

### Step 6: Generate report

Write the triage report to `reports/sast/${VERSION}-${PRODUCT}-sast-triage.md`.

Use this structure:

```markdown
# SAST Triage Report: RHOSDT ${PRODUCT} ${VERSION}

**Date:** YYYY-MM-DD
**Baseline:** ${BASELINE_VERSION} (or "none")
**Scanner:** Snyk Code via Konflux sast-snyk-check
**Component analyzed:** <which image's SARIF was used>
**Note:** All 4 component images produce identical findings (same source repo).

## Summary

| Category | Count |
|----------|-------|
| Total findings | N |
| Snyk test-flagged | N |
| Test file paths | N |
| Examples/demo | N |
| Build tooling | N |
| **Require human review** | **N** |
| New since ${BASELINE} | N |

## Findings Requiring Human Review

### [WARNING] <ruleId> — <file>:<line>

**Status:** New / Existing since <version>
**Snyk rule:** <rule description>
**Source:** <link or path>

<one-paragraph assessment>

---

### [NOTE] <ruleId> — <file>:<line>
...

## New Findings Since ${BASELINE}

<List findings with new fingerprints, even if filtered as noise —
gives the reviewer visibility into what changed>

## Noise Summary

Collapsed counts per filter category. No per-finding detail needed.

| Filter | Findings caught |
|--------|----------------|
| Snyk test-flagged | N |
| Test file paths (additional) | N |
| Examples/demo | N |
| Build tooling | N |

## Other Scanners

- **Unicode check:** N findings
- **ShellCheck:** N findings (<summary>)
- **Coverity:** N findings / not present
- **ClamAV:** all clean / <details>

## Recommendation

<One of:>
- **PASS** — no findings require action. All N findings are test/example/tooling noise.
- **REVIEW** — N finding(s) require human judgment. See "Findings Requiring Human Review" above.
- **FLAG** — N finding(s) appear to be real issues that need remediation before release.
```

### Step 7: Present results

After writing the report, present a summary to the user:

```
SAST Triage Complete: RHOSDT ${PRODUCT} ${VERSION}

Total: N findings → N require review (N new since ${BASELINE})
Recommendation: PASS / REVIEW / FLAG

Report: reports/sast/${VERSION}-${PRODUCT}-sast-triage.md

<if REVIEW or FLAG, list the specific findings that need attention>
```

## Classification Reference

These path and rule patterns were derived from analysis of RHOSDT SAST reports
across versions 3.6 through 3.11. The noise profile is stable — the same
categories recur each release with the volume scaling based on how much source
is included.

**Patterns to watch for drift:**
- New top-level directories in the source tree that aren't covered by filters
- Coverity findings outside of test YAML (historically 100% test noise, but
  Coverity has higher precision — any non-test finding is likely real)
- Warning-level findings anywhere — only 6 out of 111 in 3.11, and even those
  were mostly noise, but warnings deserve the benefit of the doubt

**Known stable noise (appears every release):**
- `scripts/snapshot-tool.py` — reDOS in Python regex (build script, not shipped)
- `opentelemetry-operator/internal/testenv/testenv.go` — TLS skip in test helper
  (not in a `/test` path so it escapes Filter 2, but it IS test infrastructure)

## Report Directory

Reports are written to `reports/sast/` in the workspace root. Create the
directory if it doesn't exist.
