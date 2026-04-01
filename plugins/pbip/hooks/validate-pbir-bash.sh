#!/bin/bash
#
# PostToolUse hook: validate JSON/PBIR syntax after Bash commands that modify PBIR files
#
# Catches modifications via python, python3, sed, awk, jq, echo, cat, cp, mv, etc.
# Extracts file paths from the Bash command, filters to PBIR project files,
# and validates JSON syntax with jq.
#
# Exit codes:
#   0 - OK or not applicable
#   2 - Blocking: invalid JSON detected
#

set -uo pipefail

INPUT=$(cat)

# Skip if jq not available
command -v jq &>/dev/null || exit 0

# Extract the bash command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[[ -z "$COMMAND" ]] && exit 0

# Extract candidate file paths from the command
# Look for paths ending in .json, .pbir, or .tmdl
# that are inside .Report/, .SemanticModel/, or .Dataset/ directories
CANDIDATES=()
while IFS= read -r path; do
    [[ -n "$path" ]] && CANDIDATES+=("$path")
done < <(echo "$COMMAND" | grep -oE '[^ "'\''><|;]+\.(json|pbir)[^ "'\''><|;]*' 2>/dev/null)

# Also try to extract quoted paths
while IFS= read -r path; do
    [[ -n "$path" ]] && CANDIDATES+=("$path")
done < <(echo "$COMMAND" | grep -oE '"[^"]+\.(json|pbir)"' 2>/dev/null | tr -d '"')

while IFS= read -r path; do
    [[ -n "$path" ]] && CANDIDATES+=("$path")
done < <(echo "$COMMAND" | grep -oE "'[^']+\.(json|pbir)'" 2>/dev/null | tr -d "'")

# No candidates found; nothing to validate
[[ ${#CANDIDATES[@]} -eq 0 ]] && exit 0

# Deduplicate
DEDUPED=()
while IFS= read -r path; do
    [[ -n "$path" ]] && DEDUPED+=("$path")
done < <(printf '%s\n' "${CANDIDATES[@]}" | sort -u)
CANDIDATES=("${DEDUPED[@]}")

# Filter to PBIR project files and validate
ERRORS=()
VALIDATED=0

for FILE_PATH in "${CANDIDATES[@]}"; do
    # Normalize path separators
    FILE_PATH="${FILE_PATH//\\//}"

    # Must be inside a PBIR report directory
    if [[ ! "$FILE_PATH" =~ \.Report/ ]]; then
        continue
    fi

    # File must exist
    [[ -f "$FILE_PATH" ]] || continue

    VALIDATED=$((VALIDATED + 1))

    # Validate JSON syntax
    if ! ERROR=$(jq empty "$FILE_PATH" 2>&1); then
        ERRORS+=("$FILE_PATH: $ERROR")
    fi
done

# No PBIR files found in command; nothing to validate
[[ $VALIDATED -eq 0 ]] && exit 0

# Report errors
if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo "PBIR JSON validation failed after Bash command:" >&2
    echo "" >&2
    for err in "${ERRORS[@]}"; do
        echo "  $err" >&2
    done
    echo "" >&2
    echo "Fix the JSON syntax error(s) before continuing." >&2
    exit 2
fi

exit 0
