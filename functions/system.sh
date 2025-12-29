# system.sh - System administration utilities
# Category: System Utilities
# Description: Shell and filesystem utilities
# Dependencies: none
# Functions: mklink, zed

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

# Open file with Zed editor
zed() {
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit zed <filepath>
Description: Open a file or directory with Zed editor
Examples:
  kit zed myfile.js
  kit zed .
  kit zed ~/projects/myproject
EOF
        return 0
    fi

    local target="$1"

    # Check if Zed.app exists
    if [[ ! -d "/Applications/Zed.app" ]]; then
        echo "Error: Zed.app not found at /Applications/Zed.app" >&2
        return 1
    fi

    # Check if target exists
    if [[ ! -e "$target" && "$target" != "." ]]; then
        echo "Error: Target '$target' does not exist" >&2
        return 1
    fi

    open "/Applications/Zed.app" "$target"
    echo "Opening '$target' in Zed editor..."
}