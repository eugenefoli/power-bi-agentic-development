#!/bin/bash
#
# PostToolUse hook: validate TMDL syntax after Bash commands that modify TMDL files
#
# Catches modifications via python, python3, sed, awk, jq, echo, cat, cp, mv, etc.
# Extracts .tmdl file paths from the Bash command and validates TMDL structure
# with tmdl-validate. No directory filter; .tmdl is a rare enough extension.
#
# Exit codes:
#   0 - OK or not applicable
#   2 - Blocking: TMDL validation error detected
#

set -uo pipefail

INPUT=$(cat)

# Skip if jq not available
command -v jq &>/dev/null || exit 0

# Extract the bash command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Find the tmdl-validate binary
VALIDATOR=""
if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
    for EXT in "" ".exe"; do
        CANDIDATE="${CLAUDE_PROJECT_DIR//\\//}/tools/tmdl-validate/target/release/tmdl-validate${EXT}"
        if [[ -x "$CANDIDATE" ]]; then
            VALIDATOR="$CANDIDATE"
            break
        fi
    done
fi
if [[ -z "$VALIDATOR" ]] && command -v tmdl-validate &>/dev/null; then
    VALIDATOR="tmdl-validate"
fi

# Skip silently if binary not available
[[ -z "$VALIDATOR" ]] && exit 0


# Extract candidate file paths from the command
CANDIDATES=()
while IFS= read -r path; do
    [[ -n "$path" ]] && CANDIDATES+=("$path")
done < <(echo "$COMMAND" | grep -oE '[^ "'\''><|;]+\.tmdl[^ "'\''><|;]*' 2>/dev/null)

# Also try to extract quoted paths
while IFS= read -r path; do
    [[ -n "$path" ]] && CANDIDATES+=("$path")
done < <(echo "$COMMAND" | grep -oE '"[^"]+\.tmdl"' 2>/dev/null | tr -d '"')

while IFS= read -r path; do
    [[ -n "$path" ]] && CANDIDATES+=("$path")
done < <(echo "$COMMAND" | grep -oE "'[^']+\.tmdl'" 2>/dev/null | tr -d "'")

# No candidates found; nothing to validate
[[ ${#CANDIDATES[@]} -eq 0 ]] && exit 0

# Deduplicate
DEDUPED=()
while IFS= read -r path; do
    [[ -n "$path" ]] && DEDUPED+=("$path")
done < <(printf '%s\n' "${CANDIDATES[@]}" | sort -u)
CANDIDATES=("${DEDUPED[@]}")

# Validate all .tmdl candidates
ERRORS=()
VALIDATED=0

for FILE_PATH in "${CANDIDATES[@]}"; do
    # Normalize path separators
    FILE_PATH="${FILE_PATH//\\//}"

    # File must exist
    [[ -f "$FILE_PATH" ]] || continue

    VALIDATED=$((VALIDATED + 1))

    # Validate TMDL structure
    if ! ERROR=$("$VALIDATOR" "$FILE_PATH" 2>&1); then
        ERRORS+=("$FILE_PATH: $ERROR")
    fi
done

# No TMDL files found in command; nothing to validate
[[ $VALIDATED -eq 0 ]] && exit 0

# Report errors
if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo "TMDL validation failed after Bash command:" >&2
    echo "" >&2
    for err in "${ERRORS[@]}"; do
        echo "  $err" >&2
    done
    echo "" >&2
    echo "Fix the TMDL structural errors before continuing." >&2
    exit 2
fi

exit 0
