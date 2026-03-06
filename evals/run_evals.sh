#!/usr/bin/env bash
# YouTube Summarizer Skill — Eval Runner
# Runs each eval case through Claude Code, captures output, checks assertions.
#
# Usage:
#   ./evals/run_evals.sh              # run all evals
#   ./evals/run_evals.sh 4            # run only eval id 4
#   ./evals/run_evals.sh 1 3          # run evals 1 and 3

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EVALS_FILE="$SCRIPT_DIR/evals.json"
RESULTS_DIR="$SCRIPT_DIR/results"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RUN_DIR="$RESULTS_DIR/$TIMESTAMP"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Check dependencies
if ! command -v claude &>/dev/null; then
  echo -e "${RED}Error: 'claude' CLI not found. Install Claude Code first.${NC}"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo -e "${RED}Error: 'jq' not found. Install with: brew install jq${NC}"
  exit 1
fi

mkdir -p "$RUN_DIR"

# Parse which eval IDs to run
if [[ $# -gt 0 ]]; then
  FILTER_IDS=("$@")
else
  FILTER_IDS=()
fi

# Read eval count
TOTAL=$(jq '.evals | length' "$EVALS_FILE")
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
EVAL_RUN_COUNT=0

echo -e "${BOLD}YouTube Summarizer — Eval Runner${NC}"
echo -e "Evals file: $EVALS_FILE"
echo -e "Results:    $RUN_DIR"
echo -e "Total evals in file: $TOTAL"
echo ""

for ((i = 0; i < TOTAL; i++)); do
  EVAL_ID=$(jq -r ".evals[$i].id" "$EVALS_FILE")
  PROMPT=$(jq -r ".evals[$i].prompt" "$EVALS_FILE")
  EXPECTED=$(jq -r ".evals[$i].expected_output" "$EVALS_FILE")

  # Filter by ID if specified
  if [[ ${#FILTER_IDS[@]} -gt 0 ]]; then
    MATCH=false
    for fid in "${FILTER_IDS[@]}"; do
      if [[ "$fid" == "$EVAL_ID" ]]; then
        MATCH=true
        break
      fi
    done
    if [[ "$MATCH" == "false" ]]; then
      continue
    fi
  fi

  EVAL_RUN_COUNT=$((EVAL_RUN_COUNT + 1))
  OUTPUT_FILE="$RUN_DIR/eval_${EVAL_ID}_output.md"
  RESULT_FILE="$RUN_DIR/eval_${EVAL_ID}_result.json"

  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}Eval #${EVAL_ID}${NC}: $PROMPT"
  echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Run Claude Code in print mode. The youtube-summarizer skill is installed
  # at ~/.claude/skills/ and auto-triggers on matching prompts (e.g. "summarize URL").
  # We unset CLAUDECODE to allow nested invocation and skip permissions for automation.
  # claude -p may write response to stderr in piped contexts, so we capture both
  # and use whichever has content.
  echo -e "  Running claude... (this may take a few minutes)"
  STDOUT_FILE="$RUN_DIR/eval_${EVAL_ID}_stdout.txt"
  STDERR_FILE="$RUN_DIR/eval_${EVAL_ID}_stderr.log"
  set +e
  echo "$PROMPT" | env -u CLAUDECODE claude -p \
    --dangerously-skip-permissions \
    1>"$STDOUT_FILE" 2>"$STDERR_FILE"
  CLAUDE_EXIT=$?
  set -e

  # Use stdout if it has content, otherwise fall back to stderr
  if [[ -s "$STDOUT_FILE" ]]; then
    CLAUDE_OUTPUT=$(<"$STDOUT_FILE")
  else
    CLAUDE_OUTPUT=$(<"$STDERR_FILE")
  fi

  if [[ $CLAUDE_EXIT -ne 0 ]]; then
    echo -e "  ${RED}SKIP${NC} — claude exited with code $CLAUDE_EXIT"
    echo -e "  See: $RUN_DIR/eval_${EVAL_ID}_stderr.log"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    continue
  fi

  # Save output
  echo "$CLAUDE_OUTPUT" > "$OUTPUT_FILE"
  echo -e "  Output saved to: $OUTPUT_FILE"

  # Run assertions
  ASSERTION_COUNT=$(jq ".evals[$i].assertions | length" "$EVALS_FILE")
  EVAL_PASS=true
  ASSERTION_RESULTS="[]"

  for ((j = 0; j < ASSERTION_COUNT; j++)); do
    A_NAME=$(jq -r ".evals[$i].assertions[$j].name" "$EVALS_FILE")
    A_TYPE=$(jq -r ".evals[$i].assertions[$j].type" "$EVALS_FILE")
    A_VALUE=$(jq -r ".evals[$i].assertions[$j].value" "$EVALS_FILE")
    A_DESC=$(jq -r ".evals[$i].assertions[$j].description" "$EVALS_FILE")

    case "$A_TYPE" in
      contains)
        if echo "$CLAUDE_OUTPUT" | grep -qF "$A_VALUE"; then
          STATUS="pass"
          echo -e "  ${GREEN}PASS${NC} $A_NAME — found '$A_VALUE'"
        else
          STATUS="fail"
          EVAL_PASS=false
          echo -e "  ${RED}FAIL${NC} $A_NAME — '$A_VALUE' not found"
          echo -e "       ${YELLOW}$A_DESC${NC}"
        fi
        ;;
      not_contains)
        if echo "$CLAUDE_OUTPUT" | grep -qF "$A_VALUE"; then
          STATUS="fail"
          EVAL_PASS=false
          echo -e "  ${RED}FAIL${NC} $A_NAME — '$A_VALUE' should NOT be present"
          echo -e "       ${YELLOW}$A_DESC${NC}"
        else
          STATUS="pass"
          echo -e "  ${GREEN}PASS${NC} $A_NAME — '$A_VALUE' correctly absent"
        fi
        ;;
      regex)
        if echo "$CLAUDE_OUTPUT" | grep -qE "$A_VALUE"; then
          STATUS="pass"
          echo -e "  ${GREEN}PASS${NC} $A_NAME — matched /$A_VALUE/"
        else
          STATUS="fail"
          EVAL_PASS=false
          echo -e "  ${RED}FAIL${NC} $A_NAME — no match for /$A_VALUE/"
          echo -e "       ${YELLOW}$A_DESC${NC}"
        fi
        ;;
      *)
        STATUS="skip"
        echo -e "  ${YELLOW}SKIP${NC} $A_NAME — unknown assertion type: $A_TYPE"
        ;;
    esac

    ASSERTION_RESULTS=$(echo "$ASSERTION_RESULTS" | jq \
      --arg name "$A_NAME" --arg status "$STATUS" --arg desc "$A_DESC" \
      '. + [{"name": $name, "status": $status, "description": $desc}]')
  done

  # Save result JSON
  if [[ "$EVAL_PASS" == "true" ]]; then
    EVAL_STATUS="pass"
    PASS_COUNT=$((PASS_COUNT + 1))
    echo -e "  ${GREEN}${BOLD}EVAL #${EVAL_ID}: PASS${NC}"
  else
    EVAL_STATUS="fail"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo -e "  ${RED}${BOLD}EVAL #${EVAL_ID}: FAIL${NC}"
  fi

  jq -n \
    --arg id "$EVAL_ID" \
    --arg prompt "$PROMPT" \
    --arg status "$EVAL_STATUS" \
    --arg expected "$EXPECTED" \
    --argjson assertions "$ASSERTION_RESULTS" \
    '{id: $id, prompt: $prompt, status: $status, expected: $expected, assertions: $assertions}' \
    > "$RESULT_FILE"

  echo ""
done

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  Ran:     $EVAL_RUN_COUNT"
echo -e "  ${GREEN}Passed:  $PASS_COUNT${NC}"
echo -e "  ${RED}Failed:  $FAIL_COUNT${NC}"
if [[ $SKIP_COUNT -gt 0 ]]; then
  echo -e "  ${YELLOW}Skipped: $SKIP_COUNT${NC}"
fi
echo -e "  Results: $RUN_DIR"
echo ""

# Write summary JSON
jq -n \
  --arg timestamp "$TIMESTAMP" \
  --arg pass "$PASS_COUNT" \
  --arg fail "$FAIL_COUNT" \
  --arg skip "$SKIP_COUNT" \
  --arg total "$EVAL_RUN_COUNT" \
  '{timestamp: $timestamp, total: ($total|tonumber), passed: ($pass|tonumber), failed: ($fail|tonumber), skipped: ($skip|tonumber)}' \
  > "$RUN_DIR/summary.json"

# Exit with failure if any eval failed
if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi
