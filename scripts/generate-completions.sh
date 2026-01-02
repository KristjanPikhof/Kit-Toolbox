#!/bin/bash
# generate-completions.sh - Verify completion system is in place
#
# Note: The completion system is now FULLY DYNAMIC.
# This script is kept for backwards compatibility and verification.
#
# The completions/_kit file automatically discovers:
#   - All functions from functions/*.sh (via # Functions: headers)
#   - All editor shortcuts from editor.conf
#   - All navigation shortcuts from shortcuts.conf
#
# No regeneration needed! The completion system updates automatically
# when you:
#   - Add new functions to category files
#   - Add editors to editor.conf
#   - Add shortcuts to shortcuts.conf
#   - Run 'kit update' (reloads shell)

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_DIR="$(dirname "$SCRIPT_DIR")"
COMPLETIONS_DIR="$EXT_DIR/completions"
COMPLETION_FILE="$COMPLETIONS_DIR/_kit"

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat << 'EOF'
Usage: generate-completions.sh
Description: Verify that the dynamic completion system is in place

The Kit completion system is FULLY DYNAMIC. It automatically discovers:
  • All functions from functions/*.sh files
  • All editor shortcuts from editor.conf
  • All navigation shortcuts from shortcuts.conf

No manual regeneration needed! When you add new functions or shortcuts,
simply reload your shell:
  source ~/.zshrc

Or restart your terminal.
EOF
    exit 0
fi

# Ensure completions directory exists
mkdir -p "$COMPLETIONS_DIR"

# Check if the completion file exists
if [[ -f "$COMPLETION_FILE" ]]; then
    # Verify it's the dynamic version
    if grep -qi "fully dynamic" "$COMPLETION_FILE" 2>/dev/null; then
        echo "✅ Dynamic completion system verified"
        echo ""
        echo "   Functions: $(grep -h "^# Functions:" "$EXT_DIR"/functions/*.sh 2>/dev/null | sed 's/.*: //' | tr ',' '\n' | wc -l | tr -d ' ')"

        # Count shortcuts (filter empty lines properly)
        if [[ -f "$EXT_DIR/shortcuts.conf" ]]; then
            local shortcuts=$(grep -v '^#' "$EXT_DIR/shortcuts.conf" | grep -v '^$' | grep -c '.' || echo "0")
            echo "   Navigation shortcuts: $shortcuts"
        fi

        # Count editors (filter empty lines properly)
        if [[ -f "$EXT_DIR/editor.conf" ]]; then
            local editors=$(grep -v '^#' "$EXT_DIR/editor.conf" | grep -v '^$' | grep -c '.' || echo "0")
            echo "   Editor shortcuts: $editors"
        fi

        echo ""
        echo "💡 The completion system updates automatically."
        echo "   Simply reload your shell: source ~/.zshrc"
        exit 0
    else
        echo "⚠️  Warning: Static completion file detected."
        echo "   The completion system should be fully dynamic."
        echo "   This is not an error, but consider updating."
    fi
else
    echo "❌ Error: Completion file not found at $COMPLETION_FILE"
    exit 1
fi
