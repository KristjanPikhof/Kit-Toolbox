#!/bin/zsh
# validate-editors.sh - Validate editor.conf file
# Checks for duplicates, unsafe commands, and function conflicts

[[ -n "$ZSH_VERSION" ]] || { echo "Run with: zsh $0" >&2; exit 1; }

# Detect directory where this script is located
SCRIPT_DIR="${${(%):-%x}:A:h}"
KIT_EXT_DIR="${KIT_EXT_DIR:-$(dirname "$SCRIPT_DIR")}"
editors_file="$KIT_EXT_DIR/editor.conf"
errors=0
warnings=0

if [[ -f "$KIT_EXT_DIR/lib/kit-core.zsh" ]]; then
    source "$KIT_EXT_DIR/lib/kit-core.zsh" || exit 1
else
    echo "❌ Error: kit-core helpers not found at $KIT_EXT_DIR/lib/kit-core.zsh" >&2
    exit 1
fi

if [[ ! -f "$editors_file" ]]; then
    echo "❌ Error: editor.conf not found at $editors_file"
    exit 1
fi

echo "🔍 Validating $editors_file"
echo ""

declare -A seen_editors

while IFS= read -r line || [[ -n "$line" ]]; do
    name="" editor_cmd="" desc=""
    _kit_parse_config_line "$line" name editor_cmd desc || continue
    [[ -z "$name" ]] && continue

    echo -n "Checking '$name': "

    has_error=0

    if ! _kit_validate_shell_identifier "$name"; then
        echo "❌ Invalid editor name"
        has_error=1
        errors=$((errors + 1))
    elif [[ -v "seen_editors[$name]" ]]; then
        echo "❌ Duplicate editor name"
        has_error=1
        errors=$((errors + 1))
    else
        seen_editors[$name]=1
    fi

    if [[ $has_error -eq 0 ]] && ! _kit_validate_editor_command "$editor_cmd"; then
        echo "❌ Unsafe editor command"
        has_error=1
        errors=$((errors + 1))
    fi

    if [[ -z "$editor_cmd" && $has_error -eq 0 ]]; then
        echo "❌ Empty editor command"
        has_error=1
        errors=$((errors + 1))
    fi

    if [[ $has_error -eq 0 ]]; then
        echo "✅"
    else
        echo ""
    fi
done < "$editors_file"

echo ""
echo "Checking for function conflicts..."
echo ""

for name in "${(@k)seen_editors}"; do
    if declare -f "$name" > /dev/null 2>&1; then
        if [[ " ${KIT_EDITOR_ALIASES[*]} " != *" $name "* ]]; then
            echo "⚠️  Warning: '$name' conflicts with existing function (editor will be skipped)"
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
    echo "❌ Validation failed. Fix issues before using editor shortcuts."
    exit 1
fi

if [[ $warnings -gt 0 ]]; then
    echo ""
    echo "⚠️  Validation completed with warnings"
    exit 0
fi

echo ""
echo "✅ All editor shortcuts validated successfully"
exit 0
