#!/bin/zsh
# loader.zsh - Kit's Toolkit loader and dispatcher
# This file initializes all functions and provides the kit command dispatcher

# ============================================================================
# ENVIRONMENT SETUP
# ============================================================================

# Detect directory where this loader.zsh is located
# Use existing KIT_EXT_DIR if set, otherwise auto-detect
if [[ -z "$KIT_EXT_DIR" ]]; then
    # Get the directory where this script (loader.zsh) is located
    export KIT_EXT_DIR="${${(%):-%x}:A:h}"
fi

# Verify base directory exists
if [[ ! -d "$KIT_EXT_DIR" ]]; then
    echo "Error: KIT_EXT_DIR not found at $KIT_EXT_DIR" >&2
    return 1
fi

# Read version from VERSION file
KIT_VERSION="${KIT_VERSION:-unknown}"
if [[ -f "$KIT_EXT_DIR/VERSION" ]]; then
    KIT_VERSION="$(cat "$KIT_EXT_DIR/VERSION" | tr -d '[:space:]')"
fi

# ============================================================================
# LOAD ALL FUNCTIONS
# ============================================================================

# Source all shell function files from functions directory
if [[ -d "$KIT_EXT_DIR/functions" ]]; then
    for file in "$KIT_EXT_DIR"/functions/*.sh; do
        if [[ -f "$file" ]]; then
            source "$file"
        fi
    done
fi

# ============================================================================
# AUTO-GENERATE NAVIGATION SHORTCUTS
# ============================================================================

KIT_NAV_ALIASES=()
_kit_generate_shortcuts() {
    local shortcuts_file="$KIT_EXT_DIR/shortcuts.conf"
    local auto_generate="${KIT_AUTO_SHORTCUTS:-true}"

    [[ "$auto_generate" != "true" ]] && return 0
    [[ ! -f "$shortcuts_file" ]] && return 0

    local conflicts=0
    local duplicates=()

    while IFS='|' read -r name shortcut_path desc; do
        [[ "$name" =~ ^# ]] && continue
        [[ -z "$name" ]] && continue

        if [[ " ${KIT_NAV_ALIASES[*]} " == *" $name "* ]]; then
            echo "❌ Error: Duplicate shortcut '$name' in shortcuts.conf" >&2
            duplicates+=("$name")
            conflicts=$((conflicts + 1))
            continue
        fi

        if declare -f "$name" > /dev/null 2>&1; then
            echo "⚠️  Warning: Shortcut '$name' conflicts with existing function - prefer shortcut behavior" >&2
        fi

        local escaped_path="${shortcut_path//\'/\\\'}"
        eval "$name() { local shortcut_name='$name'; local target_path='$escaped_path'; target_path=\"\${target_path/\\~/$HOME}\"; cd \"\$target_path\" && ls; }"

        KIT_NAV_ALIASES+=("$name")
    done < "$shortcuts_file"

    if [[ $conflicts -gt 0 ]]; then
        echo "❌ Found $conflicts shortcut conflict(s). Please fix shortcuts.conf" >&2
    fi
}

_kit_generate_shortcuts

# ============================================================================
# LOAD ZSH COMPLETIONS
# ============================================================================

if [[ -d "$KIT_EXT_DIR/completions" ]]; then
    fpath=("$KIT_EXT_DIR/completions" $fpath)
fi

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Load category registry
_kit_load_categories() {
    local categories_file="$KIT_EXT_DIR/categories.conf"
    if [[ -f "$categories_file" ]]; then
        grep -v '^#' "$categories_file" | grep -v '^$'
    fi
}

# Get category display name
_kit_get_category_name() {
    local category_id="$1"
    local categories_file="$KIT_EXT_DIR/categories.conf"
    grep "^$category_id:" "$categories_file" 2>/dev/null | cut -d: -f2
}

# Get all functions with their category and description
_kit_get_all_functions() {
    local functions_dir="$KIT_EXT_DIR/functions"

    for file in "$functions_dir"/*.sh; do
        if [[ -f "$file" ]]; then
            # Extract Category, Functions, and Description from header
            local category=$(grep "^# Category:" "$file" | head -1 | cut -d: -f2- | xargs)
            local func_list=$(grep "^# Functions:" "$file" | head -1 | cut -d: -f2- | xargs | tr ',' ' ')
            local description=$(grep "^# Description:" "$file" | head -1 | cut -d: -f2- | xargs)

            if [[ -n "$func_list" && -n "$category" ]]; then
                for func in ${=func_list}; do
                    local func_help=$(declare -f "$func" 2>/dev/null | grep -A 20 'if \[\[.*-h' | grep -E 'echo|Usage|Description' | head -1 | sed 's/.*echo "//;s/".*//;s/.*Usage: //;s/Description: //')
                    echo "$func:$category"
                done
            fi
        fi
    done
}

# ============================================================================
# MAIN DISPATCHER FUNCTION
# ============================================================================

kit() {
    local cmd="$1"
    local categories_file="$KIT_EXT_DIR/categories.conf"

    # ========================================================================
    # HELP AND INFORMATION COMMANDS
    # ========================================================================

    # Show categorized function list
    if [[ -z "$cmd" || "$cmd" == "-h" || "$cmd" == "--help" ]]; then
        # Colors
        local BLUE='\033[1;34m'
        local GREEN='\033[1;32m'
        local YELLOW='\033[1;33m'
        local CYAN='\033[1;36m'
        local GRAY='\033[0;90m'
        local BOLD='\033[1m'
        local DIM='\033[2m'
        local NC='\033[0m'

        echo ""
        echo "${BOLD}╭─────────────────────────────────────────────────────────────────╮${NC}"
        echo "${BOLD}│${NC}  ${BLUE}🛠️  Kit - Shell Toolkit${NC}                      ${DIM}v${KIT_VERSION}${NC}  ${BOLD}│${NC}"
        echo "${BOLD}╰─────────────────────────────────────────────────────────────────╯${NC}"
        echo ""

        # Count functions and shortcuts
        local functions_dir="$KIT_EXT_DIR/functions"
        local total_functions=0
        local total_categories=0

        # Group functions by category
        local processed_categories=""
        local -A category_icons=(
            ["Image Processing"]="🎨"
            ["Media Processing"]="🎬"
            ["System Utilities"]="⚙️ "
            ["Navigation Shortcuts"]="🧭"
            ["File Listing"]="📁"
        )

        for file in "$functions_dir"/*.sh; do
            if [[ ! -f "$file" ]]; then
                continue
            fi

            local category=$(grep "^# Category:" "$file" | head -1 | cut -d: -f2- | xargs)
            local func_list=$(grep "^# Functions:" "$file" | head -1 | cut -d: -f2- | xargs | tr ',' ' ')

            # Skip if we've already processed this category
            if [[ -n "$category" ]] && [[ "$processed_categories" != *"$category"* ]]; then
                processed_categories="$processed_categories|$category"
                ((total_categories++))

                # Get icon for category
                local icon="${category_icons[$category]:-📦}"

                echo "${CYAN}${icon} ${category}${NC}"
                echo "${GRAY}$( printf '%.0s─' {1..65} )${NC}"

                # Get all functions in this category file and their descriptions
                for func in ${=func_list}; do
                    ((total_functions++))

                    # Check for alias
                    local func_alias=$(declare -f "$func" 2>/dev/null | \
                        grep -o 'Alias:.*$' | head -1 | sed 's/Alias: *//' | sed 's/ *$//')

                    # Get description
                    local short_desc=$(declare -f "$func" 2>/dev/null | \
                        grep -o 'Usage:.*$' | head -1 | sed 's/Usage: kit [^ ]* *//' | sed 's/ *Example.*//' | sed 's/"$//' | cut -c1-45)
                    if [[ -z "$short_desc" ]]; then
                        short_desc=$(declare -f "$func" 2>/dev/null | \
                            grep -o 'Description:.*$' | head -1 | sed 's/Description: //' | cut -c1-45)
                    fi

                    # Format function name with alias if present
                    local func_display="$func"
                    if [[ -n "$func_alias" ]]; then
                        func_display="$func ($func_alias)"
                    fi

                    printf "  ${GREEN}%-30s${NC} ${DIM}%s${NC}\n" "$func_display" "$short_desc"
                done
                echo ""
            fi
        done

        if [[ ${#KIT_NAV_ALIASES[@]} -gt 0 ]]; then
            echo "${CYAN}🚀 Quick Navigation${NC}"
            echo "${GRAY}$( printf '%.0s─' {1..65} )${NC}"
            local shortcuts_file="$KIT_EXT_DIR/shortcuts.conf"
            for alias_name in "${KIT_NAV_ALIASES[@]}"; do
                local desc=$(awk -F'|' -v name="$alias_name" '!/^#/ && NF > 0 && $1 == name {print $3; exit}' "$shortcuts_file" 2>/dev/null || echo "")
                printf "  ${GREEN}%-22s${NC} ${DIM}%s${NC}\n" "$alias_name" "$desc"
            done
            echo ""
        fi

        echo "${CYAN}💡 Getting Started${NC}"
        echo "${GRAY}$( printf '%.0s─' {1..65} )${NC}"
        echo "  ${YELLOW}kit ${GREEN}<command>${NC} [args]     Run a function"
        echo "  ${YELLOW}kit ${GREEN}<command>${NC} -h         Show detailed help"
        echo "  ${YELLOW}kit${NC} --search <term>      Search available functions"
        echo "  ${YELLOW}kit${NC} --list-categories    List all categories"
        echo ""

        # Footer with stats
        echo "${GRAY}$( printf '%.0s─' {1..65} )${NC}"
        echo "  ${DIM}${total_functions} functions across ${total_categories} categories • ${#KIT_NAV_ALIASES[@]} shortcuts${NC}"
        echo ""

        return 0
    fi

    # List all categories
    if [[ "$cmd" == "--list-categories" ]]; then
        local CYAN='\033[1;36m'
        local GREEN='\033[1;32m'
        local GRAY='\033[0;90m'
        local DIM='\033[2m'
        local NC='\033[0m'

        echo ""
        echo "${CYAN}📂 Available Categories${NC}"
        echo "${GRAY}$( printf '%.0s─' {1..65} )${NC}"
        echo ""

        while IFS=: read -r id name desc; do
            # Count functions in this category
            local count=$(grep -l "^# Category: $name" "$KIT_EXT_DIR"/functions/*.sh 2>/dev/null | \
                          xargs grep "^# Functions:" | \
                          sed 's/.*Functions: //' | tr ',' '\n' | wc -l | tr -d ' ')
            printf "  ${GREEN}%-20s${NC} ${DIM}%s (%d functions)${NC}\n" "$name" "$desc" "$count"
        done < <(_kit_load_categories)

        echo ""
        return 0
    fi

    # Search for functions by keyword
    if [[ "$cmd" == "--search" ]]; then
        if [[ -z "$2" ]]; then
            echo "Error: --search requires a keyword" >&2
            return 2
        fi

        local keyword="$2"
        local CYAN='\033[1;36m'
        local GREEN='\033[1;32m'
        local YELLOW='\033[1;33m'
        local GRAY='\033[0;90m'
        local DIM='\033[2m'
        local NC='\033[0m'

        echo ""
        echo "${CYAN}🔍 Search results for '${YELLOW}$keyword${CYAN}'${NC}"
        echo "${GRAY}$( printf '%.0s─' {1..65} )${NC}"
        echo ""

        local found=0
        for file in "$KIT_EXT_DIR"/functions/*.sh; do
            if [[ ! -f "$file" ]]; then
                continue
            fi

            local func_list=$(grep "^# Functions:" "$file" | head -1 | cut -d: -f2- | xargs | tr ',' ' ')

            for func in ${=func_list}; do
                if [[ "$func" == *"$keyword"* ]]; then
                    local category=$(grep "^# Category:" "$file" | head -1 | cut -d: -f2- | xargs)
                    printf "  ${GREEN}%-22s${NC} ${DIM}%s${NC}\n" "$func" "$category"
                    found=$((found + 1))
                fi
            done
        done

        if [[ $found -eq 0 ]]; then
            echo "  ${DIM}No functions found matching '$keyword'${NC}"
        else
            echo ""
            echo "${GRAY}$( printf '%.0s─' {1..65} )${NC}"
            echo "  ${DIM}Found $found function(s)${NC}"
        fi
        echo ""
        return 0
    fi

    # ========================================================================
    # FUNCTION DISPATCHER
    # ========================================================================

    # Check if function exists and is declared
    if declare -f "$cmd" > /dev/null 2>&1; then
        # Function exists, call it with remaining arguments
        shift
        "$cmd" "$@"
        return $?
    else
        echo "Error: Command '$cmd' not found. Run 'kit -h' for list of available commands." >&2
        return 127
    fi
}

# ============================================================================
# INITIALIZATION COMPLETE
# ============================================================================
