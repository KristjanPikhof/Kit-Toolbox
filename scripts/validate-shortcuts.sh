#!/bin/zsh
# validate-shortcuts.sh - Validate shortcuts.conf file
# Checks for duplicates, path existence, and function conflicts

# Detect directory where this script is located
SCRIPT_DIR="${${(%):-%x}:A:h}"
KIT_EXT_DIR="${KIT_EXT_DIR:-$(dirname "$SCRIPT_DIR")}"
shortcuts_file="$KIT_EXT_DIR/shortcuts.conf"
errors=0
warnings=0

if [[ ! -f "$shortcuts_file" ]]; then
    echo "❌ Error: shortcuts.conf not found at $shortcuts_file"
    exit 1
fi

echo "🔍 Validating $shortcuts_file"
echo ""

declare -A seen_shortcuts
declare -a path_issues

while IFS='|' read -r name shortcut_path desc; do
    [[ "$name" =~ ^# ]] && continue
    [[ -z "$name" ]] && continue

    echo -n "Checking '$name': "

    has_error=0

    if [[ -v "seen_shortcuts[$name]" ]]; then
        echo "❌ Duplicate shortcut name"
        has_error=1
        errors=$((errors + 1))
    else
        seen_shortcuts[$name]=1
    fi

    expanded_path="${shortcut_path/\~/$HOME}"
    if [[ ! -d "$expanded_path" ]]; then
        echo -n "❌ Path does not exist "
        has_error=1
        errors=$((errors + 1))
        path_issues+=("$name|$expanded_path")
    fi

    if [[ $has_error -eq 0 ]]; then
        echo "✅"
    else
        echo ""
    fi
done < "$shortcuts_file"

echo ""
echo "Checking for function conflicts..."
echo ""

for name in "${(@k)seen_shortcuts}"; do
    if declare -f "$name" > /dev/null 2>&1; then
        if [[ " ${KIT_NAV_ALIASES[*]} " != *" $name "* ]]; then
            echo "⚠️  Warning: '$name' conflicts with existing function (shortcut will override)"
            warnings=$((warnings + 1))
        fi
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Results:"
echo "  Errors:   $errors"
echo "  Warnings: $warnings"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "❌ Validation failed. Fix issues before using shortcuts."
    echo ""
    if [[ ${#path_issues[@]} -gt 0 ]]; then
        echo "Path issues:"
        for issue in "${path_issues[@]}"; do
            issue_name="${issue%%|*}"
            issue_path="${issue##*|}"
            echo "  • $issue_name: $issue_path"
        done
    fi
    exit 1
fi

if [[ $warnings -gt 0 ]]; then
    echo ""
    echo "⚠️  Validation completed with warnings"
    exit 0
fi

echo ""
echo "✅ All shortcuts validated successfully"
exit 0
