# system.sh - System administration utilities
# Category: System Utilities
# Description: Shell and filesystem utilities
# Dependencies: none (Zed editor for zed function)
# Functions: mklink, zed, killports

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

# Kill processes using specified network ports
killports() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit killports <port1> [port2] [port3] ...
Description: Kill processes using specified network ports
Examples:
  kit killports 3000
  kit killports 8080 3000 9000
  kit killports 5173 3001
EOF
        return 0
    fi

    # Input validation
    if [[ -z "$1" ]]; then
        echo "Error: At least one port number is required" >&2
        return 2
    fi

    local ports=("$@")
    local killed_count=0
    local not_found_count=0
    local failed_count=0

    # Check if lsof is available
    if ! command -v lsof &> /dev/null; then
        echo "Error: 'lsof' command not found" >&2
        local os="$(_kit_detect_os)"
        case "$os" in
            macos)
                echo "This command is available by default on macOS" >&2
                ;;
            linux)
                echo "Install with: sudo apt install lsof (Debian/Ubuntu)" >&2
                echo "              sudo yum install lsof (RHEL/CentOS)" >&2
                ;;
            *)
                echo "Please install lsof for your system" >&2
                ;;
        esac
        return 1
    fi

    for port in "${ports[@]}"; do
        # Validate port is numeric
        if ! [[ "$port" =~ ^[0-9]+$ ]]; then
            echo "Error: Invalid port number '$port'. Must be numeric." >&2
            failed_count=$((failed_count + 1))
            continue
        fi

        # Validate port range
        if [[ "$port" -lt 1 || "$port" -gt 65535 ]]; then
            echo "Error: Port '$port' is out of valid range (1-65535)." >&2
            failed_count=$((failed_count + 1))
            continue
        fi

        # Find PIDs using this port
        local pids
        pids=$(lsof -ti:"$port" 2>/dev/null)

        if [[ -z "$pids" ]]; then
            echo "No processes found on port $port"
            not_found_count=$((not_found_count + 1))
            continue
        fi

        # Show process details before killing
        echo "Found process(es) on port $port:"
        for pid in $pids; do
            # Get process info
            local proc_info
            proc_info=$(ps -o pid,tty,etime,command -p "$pid" 2>/dev/null | tail -1)
            if [[ -n "$proc_info" ]]; then
                echo "  $proc_info"
            fi
        done

        # Kill the processes
        if kill -9 $pids 2>/dev/null; then
            echo "Killed process(es) on port $port (PID(s): $pids)"
            killed_count=$((killed_count + 1))
        else
            # Some PIDs might have already exited or need sudo
            local remaining_pids=""
            for pid in $pids; do
                if kill -0 "$pid" 2>/dev/null; then
                    remaining_pids="$remaining_pids $pid"
                fi
            done

            if [[ -n "$remaining_pids" ]]; then
                echo "Warning: Could not kill process(es) on port $port (PID(s):$remaining_pids)" >&2
                echo "  The process might require sudo. Try: sudo kill -9 $remaining_pids" >&2
                failed_count=$((failed_count + 1))
            else
                echo "Killed process(es) on port $port (PID(s): $pids)"
                killed_count=$((killed_count + 1))
            fi
        fi
    done

    # Summary
    echo ""
    if [[ $killed_count -gt 0 ]]; then
        echo "Killed processes on $killed_count port(s)"
    fi
    if [[ $not_found_count -gt 0 ]]; then
        echo "No processes found on $not_found_count port(s)"
    fi
    if [[ $failed_count -gt 0 ]]; then
        echo "Failed to kill processes on $failed_count port(s)" >&2
        return 1
    fi

    return 0
}
