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

# Load shared internal helpers
if [[ -f "$KIT_EXT_DIR/lib/kit-core.zsh" ]]; then
    source "$KIT_EXT_DIR/lib/kit-core.zsh" || return 1
else
    echo "Error: Kit core helpers not found at $KIT_EXT_DIR/lib/kit-core.zsh" >&2
    return 1
fi

if [[ -f "$KIT_EXT_DIR/lib/kit-files.zsh" ]]; then
    source "$KIT_EXT_DIR/lib/kit-files.zsh" || return 1
else
    echo "Error: Kit file helpers not found at $KIT_EXT_DIR/lib/kit-files.zsh" >&2
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
# Only initialize if not already set (for clean re-source support)
(( ! ${+KIT_NAV_FUNCTIONS_CREATED} )) && KIT_NAV_FUNCTIONS_CREATED=()
(( ! ${+KIT_NAV_TARGETS} )) && typeset -gA KIT_NAV_TARGETS=()
(( ! ${+KIT_NAV_DESCS} )) && typeset -gA KIT_NAV_DESCS=()

_kit_disable_kit_shortcuts() {
    local name
    for name in "${KIT_NAV_FUNCTIONS_CREATED[@]}"; do
        unfunction "$name" 2>/dev/null
        unset "KIT_NAV_TARGETS[$name]"
        unset "KIT_NAV_DESCS[$name]"
    done
    KIT_NAV_FUNCTIONS_CREATED=()
}

_kit_prune_kit_shortcuts() {
    local -a active_names=("$@")
    local name
    for name in "${KIT_NAV_FUNCTIONS_CREATED[@]}"; do
        if (( ! active_names[(Ie)$name] )); then
            unfunction "$name" 2>/dev/null
            unset "KIT_NAV_TARGETS[$name]"
            unset "KIT_NAV_DESCS[$name]"
        fi
    done
    KIT_NAV_FUNCTIONS_CREATED=("${active_names[@]}")
}

_kit_run_shortcut() {
    local shortcut_name="$1"
    if (( ! ${+KIT_NAV_TARGETS[$shortcut_name]} )); then
        echo "Error: Shortcut '$shortcut_name' not found" >&2
        return 1
    fi

    local target_path="${KIT_NAV_TARGETS[$shortcut_name]}"

    target_path="${target_path/\~/$HOME}"
    cd "$target_path" && ls
}

_kit_validate_path() {
    local shortcut_path="$1"

    # Check for path traversal attempts
    if [[ "$shortcut_path" == *"../"* ]] || [[ "$shortcut_path" == *"/.."* ]]; then
        return 1
    fi

    # Allow ~/ prefix for home directory with subpath, reject bare ~ or ~user
    if [[ "$shortcut_path" == "~" ]] || [[ "$shortcut_path" == "~/"* ]]; then
        # Only allow ~/... (home directory with subpath)
        if [[ "$shortcut_path" != "~/"* ]]; then
            # Reject bare ~
            return 1
        fi
    elif [[ "$shortcut_path" == "~"* ]]; then
        # Reject ~user patterns (e.g., ~otheruser/path)
        return 1
    fi

    # Reject shell expansion patterns that could enable command injection
    # We don't require existence here since paths may be created later
    # But we do want to catch obviously malicious patterns
    if [[ "$shortcut_path" == *'$'* ]] || [[ "$shortcut_path" == *'`'* ]] || [[ "$shortcut_path" == *'$('* ]]; then
        return 1
    fi

    return 0
}

_kit_generate_shortcuts() {
    local shortcuts_file="$KIT_EXT_DIR/shortcuts.conf"
    local auto_generate="${KIT_AUTO_SHORTCUTS:-true}"
    local -a active_names=()
    local conflicts=0 entry name shortcut_path desc

    KIT_NAV_ALIASES=()

    if [[ "$auto_generate" != "true" ]]; then
        _kit_disable_kit_shortcuts
        return 0
    fi

    if [[ ! -f "$shortcuts_file" ]]; then
        _kit_prune_kit_shortcuts
        return 0
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        name="" shortcut_path="" desc=""
        _kit_parse_config_line "$line" name shortcut_path desc || continue
        [[ -z "$name" ]] && continue

        if ! _kit_validate_shell_identifier "$name"; then
            echo "❌ Error: Invalid shortcut name '$name' in shortcuts.conf. Must be a valid shell identifier (letters, digits, underscore, not starting with digit)." >&2
            conflicts=$((conflicts + 1))
            continue
        fi

        # Validate path is safe (no traversal or command injection)
        if ! _kit_validate_path "$shortcut_path"; then
            echo "❌ Error: Invalid path '$shortcut_path' for shortcut '$name'. Path contains unsafe characters." >&2
            conflicts=$((conflicts + 1))
            continue
        fi

        if [[ " ${KIT_NAV_ALIASES[*]} " == *" $name "* ]]; then
            echo "❌ Error: Duplicate shortcut '$name' in shortcuts.conf" >&2
            conflicts=$((conflicts + 1))
            continue
        fi

        # Skip if function already exists - handle differently based on origin
        if declare -f "$name" > /dev/null 2>&1; then
            # Use explicit array index check for reliable substring-safe matching
            if (( ${KIT_NAV_FUNCTIONS_CREATED[(Ie)$name]} )); then
                # Function was created by kit on previous load - silently redefine to update config changes
                KIT_NAV_TARGETS[$name]="$shortcut_path"
                KIT_NAV_DESCS[$name]="$desc"
                eval "$name() { _kit_run_shortcut $name; }"
                KIT_NAV_ALIASES+=("$name")
                active_names+=("$name")
                continue
            fi
            # User-defined function conflicts with kit shortcut - warn user
            echo "⚠️  Warning: Shortcut '$name' conflicts with existing function - using existing function" >&2
            KIT_NAV_ALIASES+=("$name")
            continue
        fi

        KIT_NAV_TARGETS[$name]="$shortcut_path"
        KIT_NAV_DESCS[$name]="$desc"
        eval "$name() { _kit_run_shortcut $name; }"

        active_names+=("$name")
        KIT_NAV_ALIASES+=("$name")
    done < "$shortcuts_file"

    _kit_prune_kit_shortcuts "${active_names[@]}"

    if [[ $conflicts -gt 0 ]]; then
        echo "❌ Found $conflicts shortcut conflict(s). Please fix shortcuts.conf" >&2
    fi
}

_kit_generate_shortcuts

# ============================================================================
# AUTO-GENERATE EDITOR SHORTCUTS
# ============================================================================

KIT_EDITOR_ALIASES=()
# Only initialize if not already set (for clean re-source support)
(( ! ${+KIT_EDITOR_FUNCTIONS_CREATED} )) && KIT_EDITOR_FUNCTIONS_CREATED=()
(( ! ${+KIT_EDITOR_COMMANDS} )) && typeset -gA KIT_EDITOR_COMMANDS=()
(( ! ${+KIT_EDITOR_DESCS} )) && typeset -gA KIT_EDITOR_DESCS=()

_kit_disable_kit_editors() {
    local name
    for name in "${KIT_EDITOR_FUNCTIONS_CREATED[@]}"; do
        unfunction "$name" 2>/dev/null
        unset "KIT_EDITOR_COMMANDS[$name]"
        unset "KIT_EDITOR_DESCS[$name]"
    done
    KIT_EDITOR_FUNCTIONS_CREATED=()
}

_kit_prune_kit_editors() {
    local -a active_names=("$@")
    local name
    for name in "${KIT_EDITOR_FUNCTIONS_CREATED[@]}"; do
        if (( ! active_names[(Ie)$name] )); then
            unfunction "$name" 2>/dev/null
            unset "KIT_EDITOR_COMMANDS[$name]"
            unset "KIT_EDITOR_DESCS[$name]"
        fi
    done
    KIT_EDITOR_FUNCTIONS_CREATED=("${active_names[@]}")
}

_kit_run_editor() {
    local editor_name="$1"
    shift

    local editor_cmd="${KIT_EDITOR_COMMANDS[$editor_name]}"
    local desc="${KIT_EDITOR_DESCS[$editor_name]}"

    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        echo "Usage: kit $editor_name <path>..."
        echo "Description: Open one or more files or folders with $desc"
        echo ""
        echo "Examples:"
        echo "  kit $editor_name myfile.md"
        echo "  kit $editor_name first.md second.md"
        echo "  kit $editor_name ."
        return 0
    fi

    if [[ -z "$1" ]]; then
        echo "Error: Missing file or folder path" >&2
        echo "Usage: kit $editor_name <path>..." >&2
        return 2
    fi

    local -a targets=("$@")
    local target
    for target in "${targets[@]}"; do
        if [[ ! -e "$target" && "$target" != "." ]]; then
            echo "Error: '$target' does not exist" >&2
            return 1
        fi
    done

    local -a editor_argv
    editor_argv=("${(@Q)${(z)editor_cmd}}")
    if [[ ${#editor_argv[@]} -eq 0 ]]; then
        echo "Error: Editor '$editor_name' command is empty" >&2
        return 1
    fi

    "${editor_argv[@]}" "${targets[@]}"
}

_kit_generate_editors() {
    local editors_file="$KIT_EXT_DIR/editor.conf"
    local auto_generate="${KIT_AUTO_EDITORS:-true}"
    local -a active_names=()
    local conflicts=0 name editor_cmd desc line

    KIT_EDITOR_ALIASES=()

    if [[ "$auto_generate" != "true" ]]; then
        _kit_disable_kit_editors
        return 0
    fi

    if [[ ! -f "$editors_file" ]]; then
        _kit_prune_kit_editors
        return 0
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        name="" editor_cmd="" desc=""
        _kit_parse_config_line "$line" name editor_cmd desc || continue
        [[ -z "$name" ]] && continue

        if ! _kit_validate_shell_identifier "$name"; then
            echo "❌ Error: Invalid editor name '$name' in editor.conf. Must be a valid shell identifier (letters, digits, underscore, not starting with digit)." >&2
            conflicts=$((conflicts + 1))
            continue
        fi

        if ! _kit_validate_editor_command "$editor_cmd"; then
            echo "❌ Error: Invalid editor command for '$name'. Command contains unsafe characters." >&2
            conflicts=$((conflicts + 1))
            continue
        fi

        if [[ " ${KIT_EDITOR_ALIASES[*]} " == *" $name "* ]]; then
            echo "❌ Error: Duplicate editor '$name' in editor.conf" >&2
            conflicts=$((conflicts + 1))
            continue
        fi

        if declare -f "$name" > /dev/null 2>&1; then
            if (( ${KIT_EDITOR_FUNCTIONS_CREATED[(Ie)$name]} )); then
                KIT_EDITOR_COMMANDS[$name]="$editor_cmd"
                KIT_EDITOR_DESCS[$name]="$desc"
                eval "$name() { _kit_run_editor $name \"\$@\"; }"
                KIT_EDITOR_ALIASES+=("$name")
                active_names+=("$name")
                continue
            fi
            echo "⚠️  Warning: Editor '$name' conflicts with existing function - using existing function" >&2
            KIT_EDITOR_ALIASES+=("$name")
            continue
        fi

        KIT_EDITOR_COMMANDS[$name]="$editor_cmd"
        KIT_EDITOR_DESCS[$name]="$desc"
        eval "$name() { _kit_run_editor $name \"\$@\"; }"

        active_names+=("$name")
        KIT_EDITOR_ALIASES+=("$name")
    done < "$editors_file"

    _kit_prune_kit_editors "${active_names[@]}"

    if [[ $conflicts -gt 0 ]]; then
        echo "❌ Found $conflicts editor conflict(s). Please fix editor.conf" >&2
    fi
}

_kit_generate_editors

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
                        grep -o 'Usage:.*$' | head -1 | sed 's/Usage: kit [^ ]* *//' | sed 's/ *Example.*//' | sed 's/"$//')
                    if [[ -z "$short_desc" ]]; then
                        short_desc=$(declare -f "$func" 2>/dev/null | \
                            grep -o 'Description:.*$' | head -1 | sed 's/Description: //')
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
            for alias_name in "${KIT_NAV_ALIASES[@]}"; do
                local desc="${KIT_NAV_DESCS[$alias_name]}"
                if [[ -z "$desc" ]]; then
                    desc=$(_kit_find_shortcut "$KIT_EXT_DIR/shortcuts.conf" "$alias_name" | cut -d'|' -f3-)
                fi
                printf "  ${GREEN}%-22s${NC} ${DIM}%s${NC}\n" "$alias_name" "$desc"
            done
            echo ""
        fi

        if [[ ${#KIT_EDITOR_ALIASES[@]} -gt 0 ]]; then
            echo "${CYAN}✏️  Editor Shortcuts${NC}"
            echo "${GRAY}$( printf '%.0s─' {1..65} )${NC}"
            for editor_name in "${KIT_EDITOR_ALIASES[@]}"; do
                local desc="${KIT_EDITOR_DESCS[$editor_name]}"
                if [[ -z "$desc" ]]; then
                    desc=$(_kit_find_editor "$KIT_EXT_DIR/editor.conf" "$editor_name" | cut -d'|' -f3-)
                fi
                printf "  ${GREEN}%-22s${NC} ${DIM}%s${NC}\n" "$editor_name" "$desc"
            done
            echo ""
        fi

        echo "${CYAN}📂 File Command Basics${NC}"
        echo "${GRAY}$( printf '%.0s─' {1..65} )${NC}"
        echo "  ${YELLOW}kit ${GREEN}<command>${NC} file            Process one file"
        echo "  ${YELLOW}kit ${GREEN}<command>${NC} file1 file2     Process several files"
        echo "  ${YELLOW}kit ${GREEN}<command>${NC} folder          Process matching files in a folder"
        echo "  ${DIM}Folder results get a named subfolder. --recursive also includes nested folders.${NC}"
        echo "  ${DIM}Run kit <command> -h to see exact outputs, options, and examples.${NC}"
        echo ""

        echo "${CYAN}💡 Getting Started${NC}"
        echo "${GRAY}$( printf '%.0s─' {1..65} )${NC}"
        echo "  ${YELLOW}kit ${GREEN}<command>${NC} [args]     Run a function"
        echo "  ${YELLOW}kit ${GREEN}<command>${NC} -h         Show detailed help"
        echo "  ${YELLOW}kit${NC} --search <term>      Search available functions"
        echo "  ${YELLOW}kit${NC} --list-categories    List all categories"
        echo ""

        # Footer with stats
        echo "${GRAY}$( printf '%.0s─' {1..65} )${NC}"
        echo "  ${DIM}${total_functions} functions across ${total_categories} categories • ${#KIT_NAV_ALIASES[@]} shortcuts • ${#KIT_EDITOR_ALIASES[@]} editors${NC}"
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

            # Use unquoted $func_list for word splitting (works in both bash and zsh)
            for func in $func_list; do
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
