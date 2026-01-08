# aliases.sh - Navigation shortcuts and environment helpers
# Category: Navigation Shortcuts
# Description: Quick directory and environment navigation utilities
# Dependencies: none
# Functions: ccflare (intended to use with https://github.com/tombii/better-ccflare)

# Cross-platform realpath implementation
# Handles both macOS (no realpath) and Linux
_kit_realpath() {
    local path="$1"

    # If GNU realpath is available, use it
    if command -v realpath &> /dev/null; then
        realpath "$path" 2>/dev/null && return 0
    fi

    # Fallback for macOS: use Perl
    if command -v perl &> /dev/null; then
        perl -MCwd -e 'print Cwd::realpath($ARGV[0])' "$path" 2>/dev/null && return 0
    fi

    # Last resort: use zsh's built-in path resolution (requires path to exist)
    if [[ -e "$path" ]]; then
        echo "${path:A}"
        return 0
    fi

    # Path doesn't exist, return as-is
    echo "$path"
}

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
    realpath_path=$(_kit_realpath "$target_path")

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

# Load CCFlare configuration from config file
_kit_ccflare_load_config() {
    local config_file="$KIT_EXT_DIR/ccflare.conf"

    # Defaults
    CCFLARE_PROXY_URL="${CCFLARE_PROXY_URL:-http://localhost:8080}"
    ANTHROPIC_API_URL="${ANTHROPIC_API_URL:-https://api.anthropic.com}"

    # Load from config file if exists
    if [[ -f "$config_file" ]]; then
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
            # Remove leading/trailing whitespace
            key="${key// /}"
            value="${value// /}"
            # Export valid keys (proxy settings, auth, models, timeout, extra vars)
            case "$key" in
                CCFLARE_PROXY_URL|ANTHROPIC_API_URL|ANTHROPIC_AUTH_TOKEN|ANTHROPIC_MODEL|\
                ANTHROPIC_DEFAULT_OPUS_MODEL|ANTHROPIC_DEFAULT_SONNET_MODEL|ANTHROPIC_DEFAULT_HAIKU_MODEL|\
                API_TIMEOUT_MS|CCFLARE_EXTRA_VARS)
                    eval "$key=\"$value\""
                    ;;
            esac
        done < "$config_file"
    fi
}

# CCFlare proxy toggle (on/off/status)
ccflare() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit ccflare [on|off|status]
Description: Toggle CCFlare proxy for Anthropic API calls
Options:
  on      Enable CCFlare proxy
  off     Disable CCFlare proxy (preserves auth token for OAuth session)
  status  Show current CCFlare status
  (none)  Toggle current state

Configuration:
  Copy ccflare.conf.example to ccflare.conf to customize:
    cp \$KIT_EXT_DIR/ccflare.conf.example \$KIT_EXT_DIR/ccflare.conf

  Available settings:
    CCFLARE_PROXY_URL              Proxy URL (default: http://localhost:8080)
    ANTHROPIC_API_URL              Default API URL (default: https://api.anthropic.com)
    ANTHROPIC_AUTH_TOKEN           Auth token for proxy (e.g., z.ai API key)
    ANTHROPIC_MODEL                Override default model
    ANTHROPIC_DEFAULT_OPUS_MODEL   Map Opus to alternative model
    ANTHROPIC_DEFAULT_SONNET_MODEL Map Sonnet to alternative model
    ANTHROPIC_DEFAULT_HAIKU_MODEL  Map Haiku to alternative model
    API_TIMEOUT_MS                 API timeout in milliseconds

Examples:
  kit ccflare           # Toggle on/off
  kit ccflare on        # Enable proxy
  kit ccflare off       # Disable proxy
  kit ccflare status    # Show current status

Example z.ai config (ccflare.conf):
  CCFLARE_PROXY_URL=https://api.z.ai/api/anthropic
  ANTHROPIC_AUTH_TOKEN=your_zai_api_key
  API_TIMEOUT_MS=3000000
  ANTHROPIC_DEFAULT_OPUS_MODEL=GLM-4.7
  ANTHROPIC_DEFAULT_SONNET_MODEL=GLM-4.7
  ANTHROPIC_DEFAULT_HAIKU_MODEL=GLM-4.5-Air
EOF
        return 0
    fi

    # Load configuration
    _kit_ccflare_load_config

    local action="${1:-toggle}"

    # Determine current state
    local is_enabled=false
    if [[ "$ANTHROPIC_BASE_URL" == "$CCFLARE_PROXY_URL" ]]; then
        is_enabled=true
    fi

    case "$action" in
        on)
            export ANTHROPIC_BASE_URL="$CCFLARE_PROXY_URL"
            # Apply optional overrides from config
            [[ -n "${ANTHROPIC_AUTH_TOKEN:-}" ]] && export ANTHROPIC_AUTH_TOKEN
            [[ -n "${ANTHROPIC_MODEL:-}" ]] && export ANTHROPIC_MODEL
            [[ -n "${API_TIMEOUT_MS:-}" ]] && export API_TIMEOUT_MS
            # Apply model mappings
            [[ -n "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}" ]] && export ANTHROPIC_DEFAULT_OPUS_MODEL
            [[ -n "${ANTHROPIC_DEFAULT_SONNET_MODEL:-}" ]] && export ANTHROPIC_DEFAULT_SONNET_MODEL
            [[ -n "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}" ]] && export ANTHROPIC_DEFAULT_HAIKU_MODEL
            # Apply extra vars if configured
            if [[ -n "${CCFLARE_EXTRA_VARS:-}" ]]; then
                IFS=',' read -ra VARS <<< "$CCFLARE_EXTRA_VARS"
                for var in "${VARS[@]}"; do
                    export "$var"
                done
            fi
            echo "✅ CCFlare enabled"
            echo "   ANTHROPIC_BASE_URL=$ANTHROPIC_BASE_URL"
            [[ -n "${ANTHROPIC_MODEL:-}" ]] && echo "   ANTHROPIC_MODEL=$ANTHROPIC_MODEL"
            [[ -n "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}" ]] && echo "   Opus Model: $ANTHROPIC_DEFAULT_OPUS_MODEL"
            [[ -n "${ANTHROPIC_DEFAULT_SONNET_MODEL:-}" ]] && echo "   Sonnet Model: $ANTHROPIC_DEFAULT_SONNET_MODEL"
            [[ -n "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}" ]] && echo "   Haiku Model: $ANTHROPIC_DEFAULT_HAIKU_MODEL"
            [[ -n "${API_TIMEOUT_MS:-}" ]] && echo "   Timeout: ${API_TIMEOUT_MS}ms"
            ;;
        off)
            # Unset all ccflare-managed variables (restore to Claude defaults)
            # Note: ANTHROPIC_AUTH_TOKEN is NOT unset to preserve OAuth session
            unset ANTHROPIC_BASE_URL 2>/dev/null
            unset ANTHROPIC_MODEL 2>/dev/null
            unset ANTHROPIC_DEFAULT_OPUS_MODEL 2>/dev/null
            unset ANTHROPIC_DEFAULT_SONNET_MODEL 2>/dev/null
            unset ANTHROPIC_DEFAULT_HAIKU_MODEL 2>/dev/null
            unset API_TIMEOUT_MS 2>/dev/null
            # Unset extra vars if configured
            if [[ -n "${CCFLARE_EXTRA_VARS:-}" ]]; then
                IFS=',' read -ra VARS <<< "$CCFLARE_EXTRA_VARS"
                for var in "${VARS[@]}"; do
                    # Extract variable name (before '=' if present)
                    local var_name="${var%%=*}"
                    unset "$var_name" 2>/dev/null
                done
            fi
            echo "✅ CCFlare disabled (all variables unset)"
            echo "   Using Claude defaults"
            ;;
        status)
            echo "CCFlare Status:"
            echo "  Enabled: $is_enabled"
            echo "  ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL:-<not set>}"
            echo "  Proxy URL: $CCFLARE_PROXY_URL"
            echo "  API URL: $ANTHROPIC_API_URL"
            [[ -n "${ANTHROPIC_MODEL:-}" ]] && echo "  Model: $ANTHROPIC_MODEL"
            [[ -n "${ANTHROPIC_DEFAULT_OPUS_MODEL:-}" ]] && echo "  Opus Model: $ANTHROPIC_DEFAULT_OPUS_MODEL"
            [[ -n "${ANTHROPIC_DEFAULT_SONNET_MODEL:-}" ]] && echo "  Sonnet Model: $ANTHROPIC_DEFAULT_SONNET_MODEL"
            [[ -n "${ANTHROPIC_DEFAULT_HAIKU_MODEL:-}" ]] && echo "  Haiku Model: $ANTHROPIC_DEFAULT_HAIKU_MODEL"
            [[ -n "${API_TIMEOUT_MS:-}" ]] && echo "  Timeout: ${API_TIMEOUT_MS}ms"
            if [[ -f "$KIT_EXT_DIR/ccflare.conf" ]]; then
                echo "  Config: $KIT_EXT_DIR/ccflare.conf (loaded)"
            else
                echo "  Config: Using defaults (no ccflare.conf)"
            fi
            ;;
        toggle)
            if [[ "$is_enabled" == true ]]; then
                ccflare off
            else
                ccflare on
            fi
            ;;
        *)
            echo "Error: Unknown action '$action'. Use: on, off, status, or no argument to toggle." >&2
            return 2
            ;;
    esac
}
