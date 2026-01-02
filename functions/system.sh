# system.sh - System administration utilities
# Category: System Utilities
# Description: Shell and filesystem utilities
# Dependencies: none (Zed editor for zed function)
# Functions: mklink, zed

# Detect the operating system
_kit_detect_os() {
    case "$(uname -s)" in
        Darwin)  echo "macos" ;;
        Linux)   echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

# Get the Zed editor command for the current platform
_kit_get_zed_command() {
    local os="$(_kit_detect_os)"

    case "$os" in
        macos)
            if [[ -d "/Applications/Zed.app" ]]; then
                echo "open -a Zed"
                return 0
            fi
            ;;
        linux)
            if command -v zed &> /dev/null; then
                echo "zed"
                return 0
            fi
            ;;
    esac

    # Fallback: try generic zed command
    if command -v zed &> /dev/null; then
        echo "zed"
        return 0
    fi

    return 1
}

mklink() {
    if [[ "$1" == "-h" || "$1" == "--help" || $# -ne 2 ]]; then
        cat << EOF
Usage: kit mklink <target> <link_name>
Description: Create a symbolic link from target to link_name
Examples:
  kit mklink /path/to/target mylink
  kit mklink ../relative/path shortcut
EOF
        return 0
    fi

    # Input validation
    if [[ $# -ne 2 ]]; then
        echo "Error: Exactly 2 arguments required: target and link_name" >&2
        return 2
    fi

    local target="$1"
    local link_name="$2"

    # Check if target exists
    if [[ ! -e "$target" ]]; then
        echo "Error: Target '$target' does not exist" >&2
        return 1
    fi

    # Check if link already exists
    if [[ -e "$link_name" ]]; then
        echo "Error: Link destination '$link_name' already exists" >&2
        return 1
    fi

    # Create the symbolic link
    if ! ln -s "$target" "$link_name"; then
        echo "Error: Failed to create symbolic link" >&2
        return 1
    fi

    echo "Created symbolic link: $link_name -> $target"
}

# Open file with Zed editor (cross-platform)
zed() {
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit zed <filepath>
Description: Open a file or directory with Zed editor
Platform support:
  - macOS: Uses Zed.app from /Applications
  - Linux: Uses 'zed' command from PATH
Examples:
  kit zed myfile.js
  kit zed .
  kit zed ~/projects/myproject
EOF
        return 0
    fi

    local target="$1"
    local zed_cmd

    # Check if target exists
    if [[ ! -e "$target" && "$target" != "." ]]; then
        echo "Error: Target '$target' does not exist" >&2
        return 1
    fi

    # Get the appropriate Zed command
    zed_cmd=$(_kit_get_zed_command)

    if [[ -z "$zed_cmd" ]]; then
        local os="$(_kit_detect_os)"
        case "$os" in
            macos)
                echo "Error: Zed.app not found at /Applications/Zed.app" >&2
                echo "Install Zed from https://zed.dev" >&2
                ;;
            linux)
                echo "Error: 'zed' command not found in PATH" >&2
                echo "Install Zed from https://zed.dev/download" >&2
                ;;
            *)
                echo "Error: Zed editor not found" >&2
                echo "Install from https://zed.dev" >&2
                ;;
        esac
        return 1
    fi

    echo "Opening '$target' in Zed editor..."

    # Execute the appropriate command
    case "$zed_cmd" in
        "open -a Zed")
            open -a Zed "$target"
            ;;
        *)
            "$zed_cmd" "$target"
            ;;
    esac
}