#!/bin/bash
# validate-pattern.sh - Validate function files against kit_pattern.md
#
# Checks that all functions follow the established pattern including:
# - Help block present
# - Input validation
# - Error handling with proper exit codes
# - Category header present
# - Function documented in file header

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_DIR="$(dirname "$SCRIPT_DIR")"
FUNCTIONS_DIR="$EXT_DIR/functions"

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat << 'EOF'
Usage: validate-pattern.sh [file.sh ...]
Description: Validate function files against kit_pattern.md pattern requirements
Examples:
  ./scripts/validate-pattern.sh functions/images.sh
  ./scripts/validate-pattern.sh functions/*.sh
  ./scripts/validate-pattern.sh  # Validate all files

Checks for:
  ✓ Category header present
  ✓ Functions list in header
  ✓ Help block (-h/--help support)
  ✓ Input validation
  ✓ Error messages to stderr
  ✓ Exit codes (0, 1, 2)
  ✓ Function documented in header
EOF
    exit 0
fi

# If no arguments, validate all function files
if [[ $# -eq 0 ]]; then
    set -- "$FUNCTIONS_DIR"/*.sh
fi

ERRORS=0
WARNINGS=0
CHECKED=0

for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        echo "⚠️  File not found: $file" >&2
        continue
    fi

    echo "🔍 Checking: $(basename "$file")"
    CHECKED=$((CHECKED + 1))
    FILE_ERRORS=0

    # Check 1: Category header
    if ! grep -q "^# Category:" "$file"; then
        echo "  ❌ Missing: Category header"
        FILE_ERRORS=$((FILE_ERRORS + 1))
    else
        echo "  ✓ Category header"
    fi

    # Check 2: Functions header
    if ! grep -q "^# Functions:" "$file"; then
        echo "  ❌ Missing: Functions list in header"
        FILE_ERRORS=$((FILE_ERRORS + 1))
    else
        echo "  ✓ Functions list"
    fi

    # Check 3: Dependencies header
    if ! grep -q "^# Dependencies:" "$file"; then
        echo "  ⚠️  Missing: Dependencies header"
        WARNINGS=$((WARNINGS + 1))
    else
        echo "  ✓ Dependencies header"
    fi

    # Check each function in the file
    while IFS= read -r func_name; do
        func_name=$(echo "$func_name" | xargs)
        if [[ -z "$func_name" ]]; then
            continue
        fi

        # Check 4: Function help block
        if grep -q "if \[\[\s*\"\$1\"\s*==\s*\"-h\"" "$file"; then
            echo "  ✓ Help block for $func_name"
        else
            echo "  ⚠️  Missing: Help block (-h support) for $func_name"
            WARNINGS=$((WARNINGS + 1))
        fi

        # Check 5: Error messages to stderr
        if grep -q "&2" "$file"; then
            echo "  ✓ Error messages to stderr"
        else
            echo "  ⚠️  Warning: No errors to stderr (&2) found"
            WARNINGS=$((WARNINGS + 1))
        fi

        # Check 6: Exit code 2 for invalid usage
        if grep -q "return 2" "$file"; then
            echo "  ✓ Exit code 2 for invalid usage"
        else
            echo "  ⚠️  Missing: Exit code 2 for invalid usage"
            WARNINGS=$((WARNINGS + 1))
        fi

        # Check 7: Exit code 1 for errors
        if grep -q "return 1" "$file"; then
            echo "  ✓ Exit code 1 for errors"
        else
            echo "  ⚠️  Missing: Exit code 1 for errors"
            WARNINGS=$((WARNINGS + 1))
        fi

    done < <(grep "^# Functions:" "$file" | cut -d: -f2- | tr ',' '\n')

    if [[ $FILE_ERRORS -gt 0 ]]; then
        ERRORS=$((ERRORS + FILE_ERRORS))
    fi

    echo ""
done

# Summary
echo "📊 Validation Summary"
echo "===================="
echo "Files checked: $CHECKED"
echo "Errors: $ERRORS"
echo "Warnings: $WARNINGS"
echo ""

if [[ $ERRORS -eq 0 ]]; then
    echo "✅ All checks passed!"
    exit 0
else
    echo "❌ Some errors found. Please review and fix."
    exit 1
fi
