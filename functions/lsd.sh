# lsd.sh - Enhanced file listing utilities using lsd
# Category: File Listing
# Description: File listing utilities with enhanced formatting using lsd
# Dependencies: lsd (brew install lsd)
# Functions: list-files, list-all, list-reverse, list-all-reverse, list-tree

# Check if lsd is installed
_check_lsd() {
    if ! command -v lsd &> /dev/null; then
        echo "Error: lsd not installed. Install with: brew install lsd" >&2
        return 1
    fi
}

# List files in long format sorted by modification time
list-files() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit list-files [directory]
Alias: kls
Description: List files in long format sorted by modification time (newest first)
Example:
  kit list-files          # Current directory
  kit kls ~/projects      # Using alias
EOF
        return 0
    fi

    _check_lsd || return 1
    lsd -lt "${1:-.}"
}

kls() {
    list-files "$@"
}

# List all files including hidden files in long format
list-all() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit list-all [directory]
Alias: kla
Description: List all files including hidden (dot) files in long format, sorted by modification time
Example:
  kit list-all          # Current directory
  kit kla ~/.config     # Using alias
EOF
        return 0
    fi

    _check_lsd || return 1
    lsd -lat "${1:-.}"
}

kla() {
    list-all "$@"
}

# List files in long format in reverse order (oldest first)
list-reverse() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit list-reverse [directory]
Alias: ksr
Description: List files in long format in reverse order (oldest first)
Example:
  kit list-reverse          # Current directory
  kit ksr ~/downloads       # Using alias
EOF
        return 0
    fi

    _check_lsd || return 1
    lsd -ltr "${1:-.}"
}

ksr() {
    list-reverse "$@"
}

# List all files including hidden, in reverse order
list-all-reverse() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit list-all-reverse [directory]
Alias: kar
Description: List all files including hidden (dot) files in reverse order (oldest first)
Example:
  kit list-all-reverse          # Current directory
  kit kar ~/archive             # Using alias
EOF
        return 0
    fi

    _check_lsd || return 1
    lsd -latr "${1:-.}"
}

kar() {
    list-all-reverse "$@"
}

# Display directory contents as tree structure
list-tree() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit list-tree [directory]
Alias: klt
Description: Display directory contents as a tree structure
Example:
  kit list-tree          # Current directory
  kit klt ~/project      # Using alias
EOF
        return 0
    fi

    _check_lsd || return 1
    lsd --tree "${1:-.}"
}

klt() {
    list-tree "$@"
}


