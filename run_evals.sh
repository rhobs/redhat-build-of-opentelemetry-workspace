#!/bin/bash
# Trigger eval runner for Claude Code skills
# Tests whether a skill triggers correctly on expected prompts
# and does NOT trigger on unrelated prompts.
#
# Usage:
#   ./run_evals.sh <path/to/evals.json>
#   ./run_evals.sh <path/to/evals.json> --positive-only
#   ./run_evals.sh <path/to/evals.json> --negative-only
#   ./run_evals.sh <path/to/evals.json> --id 3

set -euo pipefail

if [[ $# -lt 1 || "$1" == --* ]]; then
  echo "Usage: $0 <path/to/evals.json> [--positive-only|--negative-only|--id N]"
  exit 1
fi

EVALS_FILE="$1"
shift

if [[ ! -f "$EVALS_FILE" ]]; then
  echo "Error: $EVALS_FILE not found"
  exit 1
fi

EVALS_DIR="$(cd "$(dirname "$EVALS_FILE")" && pwd)"
RESULTS_DIR="$EVALS_DIR/results"
SKILL_NAME=$(jq -r '.skill_name' "$EVALS_FILE")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUN_DIR="$RESULTS_DIR/$TIMESTAMP"

mkdir -p "$RUN_DIR"

POSITIVE_ONLY=false
NEGATIVE_ONLY=false
SPECIFIC_ID=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --positive-only) POSITIVE_ONLY=true; shift ;;
    --negative-only) NEGATIVE_ONLY=true; shift ;;
    --id) SPECIFIC_ID="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Build trigger pattern from evals.json if present, otherwise match the skill name
TRIGGER_PATTERN=$(jq -r '.trigger_pattern // empty' "$EVALS_FILE")
if [[ -z "$TRIGGER_PATTERN" ]]; then
  TRIGGER_PATTERN="$SKILL_NAME"
fi

echo "=== Skill: $SKILL_NAME ==="
echo "=== Trigger pattern: $TRIGGER_PATTERN ==="
echo ""

PASS=0
FAIL=0
TOTAL=0

run_eval() {
  local id="$1"
  local prompt="$2"
  local expected="$3"
  local is_negative="${4:-false}"

  TOTAL=$((TOTAL + 1))
  local label="eval-$id"
  if [[ "$is_negative" == "true" ]]; then
    label="neg-$id"
  fi

  echo "--- [$label] Running: $prompt"

  local output_file="$RUN_DIR/${label}.txt"
  local result

  if [[ "$is_negative" == "true" ]]; then
    # Run from /tmp so Claude doesn't load project plugins/skills
    if result=$(cd /tmp && claude -p "$prompt" --output-format text </dev/null 2>&1); then
      echo "$result" > "$output_file"
    else
      echo "ERROR: claude command failed" > "$output_file"
      echo "$result" >> "$output_file"
    fi
  else
    if result=$(claude -p "$prompt" --output-format text </dev/null 2>&1); then
      echo "$result" > "$output_file"
    else
      echo "ERROR: claude command failed" > "$output_file"
      echo "$result" >> "$output_file"
    fi
  fi

  local triggered=false
  if grep -qiE "$TRIGGER_PATTERN" "$output_file" 2>/dev/null; then
    triggered=true
  fi

  if [[ "$is_negative" == "true" ]]; then
    if [[ "$triggered" == "false" ]]; then
      echo "  PASS (correctly did not trigger)"
      PASS=$((PASS + 1))
      echo "PASS" > "$RUN_DIR/${label}.status"
    else
      echo "  FAIL (incorrectly triggered on unrelated prompt)"
      FAIL=$((FAIL + 1))
      echo "FAIL" > "$RUN_DIR/${label}.status"
    fi
  else
    if [[ "$triggered" == "true" ]]; then
      echo "  PASS (skill triggered)"
      PASS=$((PASS + 1))
      echo "PASS" > "$RUN_DIR/${label}.status"
    else
      echo "  FAIL (skill did not trigger)"
      FAIL=$((FAIL + 1))
      echo "FAIL" > "$RUN_DIR/${label}.status"
    fi
  fi
}

if [[ "$NEGATIVE_ONLY" != "true" ]]; then
  echo "=== Positive trigger evals ==="
  while IFS= read -r eval_json; do
    id=$(echo "$eval_json" | jq -r '.id')
    if [[ -n "$SPECIFIC_ID" && "$id" != "$SPECIFIC_ID" ]]; then
      continue
    fi
    prompt=$(echo "$eval_json" | jq -r '.prompt')
    expected=$(echo "$eval_json" | jq -r '.expected_output')
    run_eval "$id" "$prompt" "$expected" "false"
  done < <(jq -c '.evals[]' "$EVALS_FILE")
fi

if [[ "$POSITIVE_ONLY" != "true" && -z "$SPECIFIC_ID" ]]; then
  echo ""
  echo "=== Negative trigger evals ==="
  while IFS= read -r eval_json; do
    id=$(echo "$eval_json" | jq -r '.id')
    prompt=$(echo "$eval_json" | jq -r '.prompt')
    expected=$(echo "$eval_json" | jq -r '.expected_output')
    run_eval "$id" "$prompt" "$expected" "true"
  done < <(jq -c '.negative_evals[]' "$EVALS_FILE")
fi

echo ""
echo "=== Results ==="
echo "Total: $TOTAL  Pass: $PASS  Fail: $FAIL"
if [[ $TOTAL -gt 0 ]]; then
  RATE=$((PASS * 100 / TOTAL))
  echo "Pass rate: ${RATE}%"
fi
echo "Results saved to: $RUN_DIR"

jq -n \
  --arg skill "$SKILL_NAME" \
  --arg timestamp "$TIMESTAMP" \
  --argjson total "$TOTAL" \
  --argjson pass "$PASS" \
  --argjson fail "$FAIL" \
  '{skill: $skill, timestamp: $timestamp, total: $total, pass: $pass, fail: $fail, pass_rate: (if $total > 0 then ($pass * 100 / $total) else 0 end)}' \
  > "$RUN_DIR/summary.json"

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi