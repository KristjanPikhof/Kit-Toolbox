# aliases.sh - Navigation shortcuts and environment helpers
# Category: Navigation Shortcuts
# Description: Quick directory and environment navigation utilities
# Dependencies: none
# Functions: ccflare-on, ccflare-off

# Navigate to a named directory shortcut (DEPRECATED - use shortcuts directly)
goto() {
    echo "⚠️  Warning: 'goto' is deprecated. Use shortcuts directly: kit <shortcut_name>" >&2
    echo "   Example: kit claude instead of kit goto claude" >&2
    echo ""

    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit goto <shortcut_name> [DEPRECATED]
Description: Navigate to a pre-configured directory shortcut
Deprecated: Use shortcuts directly (kit <shortcut_name>)

Available shortcuts:
EOF
        local shortcuts_file="$KIT_EXT_DIR/shortcuts.conf"
        if [[ -f "$shortcuts_file" ]]; then
            awk -F'|' '!/^#/ && NF > 0 {printf "  %-15s %s\n", $1":", $3}' "$shortcuts_file"
        else
            echo "  (No shortcuts configured yet)"
        fi
        return 0
    fi

    local shortcut_name="$1"
    local shortcuts_file="$KIT_EXT_DIR/shortcuts.conf"

    if [[ ! -f "$shortcuts_file" ]]; then
        echo "Error: Shortcuts file not found at $shortcuts_file" >&2
        return 1
    fi

    local target_path
    target_path=$(awk -F'|' -v name="$shortcut_name" '!/^#/ && NF > 0 && $1 == name {print $2; exit}' "$shortcuts_file")

    if [[ -z "$target_path" ]]; then
        echo "Error: Shortcut '$shortcut_name' not found" >&2
        echo "Available shortcuts:" >&2
        awk -F'|' '!/^#/ && NF > 0 {printf "  %-15s %s\n", $1":", $3}' "$shortcuts_file" >&2
        return 1
    fi

    target_path="${target_path/\~/$HOME}"
    local realpath_path
    realpath_path=$(realpath "$target_path" 2>/dev/null || echo "$target_path")

    if [[ "$realpath_path" != "$HOME"* && "$realpath_path" != /tmp/* && "$realpath_path" != /var/folders/* ]]; then
        echo "Error: Path outside allowed directories" >&2
        return 1
    fi

    if [[ ! -d "$realpath_path" ]]; then
        echo "Error: Directory does not exist: $realpath_path" >&2
        return 1
    fi

    cd "$realpath_path" && ls
}

# Enable CCFlare proxy
ccflare-on() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit ccflare-on
Description: Enable CCFlare proxy by setting ANTHROPIC_BASE_URL to localhost:8080
Example: kit ccflare-on
EOF
        return 0
    fi

    export ANTHROPIC_BASE_URL="http://localhost:8080"
    echo "✅ CCFlare enabled: ANTHROPIC_BASE_URL=$ANTHROPIC_BASE_URL"
}

# Disable CCFlare proxy
ccflare-off() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit ccflare-off
Description: Disable CCFlare proxy and reset ANTHROPIC_BASE_URL to default API endpoint
Example: kit ccflare-off
EOF
        return 0
    fi

    export ANTHROPIC_BASE_URL="https://api.anthropic.com"
    echo "✅ CCFlare disabled: ANTHROPIC_BASE_URL=$ANTHROPIC_BASE_URL"
}
