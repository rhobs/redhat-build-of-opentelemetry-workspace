#!/usr/bin/env bash
# Run regression detection for Red Hat build of OpenTelemetry upstream changes.
#
# Repos must be cloned first via: make clone-repos
#
# ZERO-MAINTENANCE: all build metadata (component list, base versions,
# release branch) is derived from konflux-opentelemetry at runtime.
#
# Usage:
#   ./scripts/run-regression-detection.sh                              # full analysis (current release)
#   ./scripts/run-regression-detection.sh --release-branch rhosdt-3.10 # analyze a specific release
#   ./scripts/run-regression-detection.sh --method changelog           # single method
#
# Environment variables:
#   REPO_KONFLUX             Override konflux-opentelemetry repo path
#   REPO_OPERATOR            Override operator repo path
#   REPO_COLLECTOR_CONTRIB   Override collector-contrib repo path
#   REPO_COLLECTOR_CORE      Override collector-core repo path
#   REPO_QE_TESTS            Override QE tests repo path
#   REPO_OPENSHIFT_DOCS      Override openshift-docs repo path
#   ANTHROPIC_API_KEY        Required for Anthropic API auth
#   CLAUDE_CODE_USE_VERTEX   Set to "1" to use Vertex AI instead

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

METHOD="all"
RELEASE_BRANCH=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --method METHOD              Run one method: changelog, code-diff, feature-gates, issues, doc-validation, test-coverage, dependencies
  --release-branch BRANCH      Analyze a specific release branch in konflux-opentelemetry (e.g., rhosdt-3.10).
                               Defaults to the branch in .gitmodules (current release).
  --help                       Show this help

Environment:
  REPO_KONFLUX               Override konflux-opentelemetry path (source of truth)
  REPO_OPERATOR              Override operator repo path
  REPO_COLLECTOR_CONTRIB     Override collector-contrib repo path
  REPO_COLLECTOR_CORE        Override collector-core repo path
  REPO_QE_TESTS              Override QE tests repo path
  REPO_OPENSHIFT_DOCS        Override openshift-docs path
  ANTHROPIC_API_KEY          Anthropic API key (or use CLAUDE_CODE_USE_VERTEX=1)
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --method) METHOD="$2"; shift 2 ;;
    --release-branch) RELEASE_BRANCH="$2"; shift 2 ;;
    --help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Resolve repo path: env var override → workspace subdirectory
resolve_repo() {
  local env_var="$1"
  local repo_name="$2"

  local env_val="${!env_var:-}"
  if [[ -n "$env_val" && -d "$env_val/.git" ]]; then
    echo "$env_val"; return
  fi

  local subdir="$WORKSPACE_DIR/$repo_name"
  if [[ -d "$subdir/.git" ]]; then
    echo "$(cd "$subdir" && pwd)"; return
  fi

  echo ""
}

KONFLUX_PATH=$(resolve_repo "REPO_KONFLUX" "konflux-opentelemetry")
OPERATOR_PATH=$(resolve_repo "REPO_OPERATOR" "opentelemetry-operator")
CONTRIB_PATH=$(resolve_repo "REPO_COLLECTOR_CONTRIB" "opentelemetry-collector-contrib")
CORE_PATH=$(resolve_repo "REPO_COLLECTOR_CORE" "opentelemetry-collector")
QE_PATH=$(resolve_repo "REPO_QE_TESTS" "distributed-tracing-qe")
DOCS_PATH=$(resolve_repo "REPO_OPENSHIFT_DOCS" "openshift-docs")

# Validate required repos
missing=()
[[ -z "$KONFLUX_PATH" ]] && missing+=("konflux-opentelemetry")
[[ -z "$OPERATOR_PATH" ]] && missing+=("opentelemetry-operator")
[[ -z "$CONTRIB_PATH" ]] && missing+=("opentelemetry-collector-contrib")
[[ -z "$CORE_PATH" ]] && missing+=("opentelemetry-collector")

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "ERROR: Required repos not found: ${missing[*]}"
  echo "Run 'make clone-repos' first, or set REPO_* env vars."
  exit 1
fi

echo "=== Regression Detection ==="
echo "Konflux (source of truth): $KONFLUX_PATH"
echo "Operator:                  $OPERATOR_PATH"
echo "Collector-contrib:         $CONTRIB_PATH"
echo "Collector-core:            $CORE_PATH"
echo "Docs:                      ${DOCS_PATH:-'(not available)'}"
echo "QE tests:                  ${QE_PATH:-'(not available)'}"
echo "Method:                    $METHOD"
echo "Release branch:            ${RELEASE_BRANCH:-'(auto-detect from .gitmodules)'}"
echo ""

# Create reports directory
REPORTS_DIR="$WORKSPACE_DIR/reports"
REPORT_DATE=$(date +%Y-%m-%d)
mkdir -p "$REPORTS_DIR"

# Build the workflow args as JSON (using jq for safe escaping)
WORKFLOW_ARGS=$(jq -n \
  --arg konflux "$KONFLUX_PATH" \
  --arg operator "$OPERATOR_PATH" \
  --arg contrib "$CONTRIB_PATH" \
  --arg core "$CORE_PATH" \
  --arg qe "$QE_PATH" \
  --arg docs "$DOCS_PATH" \
  --arg method "$METHOD" \
  --arg release_branch "$RELEASE_BRANCH" \
  '{konflux_path: $konflux, operator_path: $operator, contrib_path: $contrib, core_path: $core, qe_path: $qe, docs_path: $docs, method: $method, release_branch: $release_branch}')

# Run Claude Code with the workflow
echo "Starting regression detection workflow..."
claude -p "Run the regression-detection workflow with these args: $WORKFLOW_ARGS

After the workflow completes:
1. Write the markdown report to $REPORTS_DIR/regression-report-${REPORT_DATE}.md
2. Write the JSON summary to $REPORTS_DIR/regression-summary-${REPORT_DATE}.json
3. Print a brief summary of findings to stdout." \
  --output-format text \
  --allowedTools "Bash,Read,Write,Edit,Workflow,Agent" \
  --max-budget-usd 25 \
  </dev/null

echo ""
echo "=== Done ==="
echo "Reports written to: $REPORTS_DIR/"
ls -la "$REPORTS_DIR"/regression-*"${REPORT_DATE}"* 2>/dev/null || echo "(no reports generated)"
