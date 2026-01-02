# system.sh - System administration utilities
# Category: System Utilities
# Description: Shell and filesystem utilities
# Dependencies: none (Zed editor for zed function)
# Functions: mklink, zed, killports, uninstall, update

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

# Uninstall Kit's Toolkit from the system
uninstall() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit uninstall [--purge]
Description: Remove Kit's Toolkit configuration from your zsh
Options:
  --purge    Also remove the Kit installation directory
Examples:
  kit uninstall           # Remove config only, keep directory
  kit uninstall --purge   # Remove config and delete directory
EOF
        return 0
    fi

    local purge_dir=false
    if [[ "$1" == "--purge" ]]; then
        purge_dir=true
    fi

    # Pattern to identify Kit configuration block (version-agnostic)
    # Matches: "# Kit X.Y.Z - Shell Toolkit"
    local kit_marker_pattern='# Kit .* - Shell Toolkit'

    # Check if KIT_EXT_DIR is set
    if [[ -z "$KIT_EXT_DIR" ]]; then
        echo "Error: KIT_EXT_DIR not found. Kit installation not detected." >&2
        echo "Note: If you uninstalled Kit in a different terminal session," >&2
        echo "      KIT_EXT_DIR may not be set in this session." >&2
        echo "" >&2
        echo "You can still uninstall manually by removing the Kit configuration block" >&2
        echo "from your ~/.zshrc file (look for '# Kit X.Y.Z - Shell Toolkit')." >&2
        return 1
    fi

    # Verify the directory exists and looks like a kit installation
    if [[ ! -d "$KIT_EXT_DIR" ]]; then
        echo "Warning: KIT_EXT_DIR '$KIT_EXT_DIR' does not exist." >&2
        echo "The Kit directory may have already been removed." >&2
        return 1
    fi

    if [[ ! -f "$KIT_EXT_DIR/loader.zsh" ]]; then
        echo "Warning: '$KIT_EXT_DIR' does not contain a valid Kit installation." >&2
        echo "Expected to find: loader.zsh" >&2
        return 1
    fi

    # Detect zsh config file (respects ZDOTDIR)
    local zdotdir="${ZDOTDIR:-$HOME}"
    # Build config file list, avoiding duplicates when ZDOTDIR is not set
    local config_files=("$zdotdir/.zshrc")
    [[ -n "$ZDOTDIR" ]] && config_files+=("$HOME/.zshrc")
    config_files+=("$zdotdir/.zprofile")
    [[ -n "$ZDOTDIR" ]] && config_files+=("$HOME/.zprofile")
    local config_found=false
    local active_config=""

    # Find which config file has Kit installed
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]] && grep -qE "$kit_marker_pattern" "$config_file" 2>/dev/null; then
            config_found=true
            active_config="$config_file"
            break
        fi
    done

    if [[ "$config_found" == false ]]; then
        echo "Warning: No Kit configuration found in checked locations:" >&2
        for cf in "${config_files[@]}"; do
            if [[ -f "$cf" ]]; then
                echo "  - $cf (no Kit config found)" >&2
            else
                echo "  - $cf (file does not exist)" >&2
            fi
        done
        echo "" >&2
        echo "It may have already been removed, or Kit was configured in a custom location." >&2
        echo "Please check your zsh configuration manually for the '# Kit X.Y.Z - Shell Toolkit' marker." >&2
        return 1
    fi

    echo "Found Kit configuration in: $active_config"

    # Create backup before making changes
    local backup="$active_config.backup.uninstall.$(date +%Y%m%d_%H%M%S)"
    cp "$active_config" "$backup"
    echo "Created backup: $backup"

    # Remove Kit configuration from config file
    echo "Removing Kit configuration from $active_config..."

    # Use temp file for processing
    local tmp_file="$active_config.tmp"

    # Remove lines between the Kit marker and the line that sources loader.zsh
    # Using awk for cross-platform compatibility (macOS/BSD and Linux/GNU)
    # Pattern matches version-agnostic marker: "# Kit X.Y.Z - Shell Toolkit"
    # Pattern handles various quoting styles:
    #   source "$KIT_EXT_DIR/loader.zsh"
    #   source $KIT_EXT_DIR/loader.zsh
    #   . "$KIT_EXT_DIR/loader.zsh"
    #   . $KIT_EXT_DIR/loader.zsh
    awk -v marker="$kit_marker_pattern" '
        $0 ~ marker { in_kit_block = 1; next }
        in_kit_block && /loader\.zsh/ { in_kit_block = 0; next }
        !in_kit_block { print }
    ' "$active_config" > "$tmp_file"
    mv "$tmp_file" "$active_config"

    # Verify configuration was removed by checking for the Kit marker
    if ! grep -qE "$kit_marker_pattern" "$active_config" 2>/dev/null; then
        echo "Successfully removed Kit configuration from $active_config"
    else
        echo "Warning: Some Kit configuration may remain in $active_config" >&2
        echo "Please check manually for the '# Kit X.Y.Z - Shell Toolkit' marker and source lines" >&2
    fi

    # Ask about removing kit directory (or do it if --purge was used)
    echo ""
    if [[ "$purge_dir" == true ]]; then
        echo "Removing Kit installation directory: $KIT_EXT_DIR"
        rm -rf "$KIT_EXT_DIR"
        echo "Kit installation directory removed"
    else
        echo "Kit installation directory kept at: $KIT_EXT_DIR"
        echo "To remove it later, run: kit uninstall --purge"
    fi

    # Show how to reload
    echo ""
    echo "Uninstall complete. To apply changes:"
    echo "  1. Open a new terminal window, or"
    echo "  2. Run: source ~/.zshrc"
    echo ""
    echo "Your backup is saved at: $backup"

    return 0
}

# Update Kit's Toolkit to the latest version
update() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit update [--check-only]
Description: Update Kit's Toolkit to the latest version
Options:
  --check-only    Only check for updates, don't install
Examples:
  kit update           # Check for updates and install if available
  kit update --check-only  # Only check, don't install
EOF
        return 0
    fi

    local check_only=false
    if [[ "$1" == "--check-only" ]]; then
        check_only=true
    fi

    # Check if KIT_EXT_DIR is set
    if [[ -z "$KIT_EXT_DIR" ]]; then
        echo "Error: KIT_EXT_DIR not found. Kit installation not detected." >&2
        return 1
    fi

    # Check if KIT_EXT_DIR is a git repository
    if [[ ! -d "$KIT_EXT_DIR/.git" ]]; then
        echo "Error: Kit installation is not a git repository." >&2
        echo "Your Kit installation may have been downloaded as a zip file." >&2
        echo "To update, please re-clone or download the latest version from:" >&2
        echo "  https://github.com/kristjanpikhof/kit-toolbox" >&2
        return 1
    fi

    # Check if git is available
    if ! command -v git &> /dev/null; then
        echo "Error: git is not installed." >&2
        echo "Please install git to use the update command." >&2
        return 1
    fi

    # Read current version
    local current_version="unknown"
    if [[ -f "$KIT_EXT_DIR/VERSION" ]]; then
        current_version="$(cat "$KIT_EXT_DIR/VERSION" | tr -d '[:space:]')"
    fi

    echo "Kit's Toolkit"
    echo "Current version: ${current_version}"
    echo ""

    # Save current branch
    cd "$KIT_EXT_DIR" || return 1
    local current_branch="$(git branch --show-current 2>/dev/null || echo "HEAD")"

    echo "Checking for updates..."
    # Fetch latest changes without checking them out
    git fetch -q origin 2>/dev/null

    if [[ $? -ne 0 ]]; then
        echo "Warning: Could not fetch updates. Check your internet connection." >&2
        return 1
    fi

    # Get local and remote commit hashes
    local local_commit="$(git rev-parse HEAD 2>/dev/null)"
    local remote_commit="$(git rev-parse @{u} 2>/dev/null)"

    if [[ "$local_commit" == "$remote_commit" ]]; then
        echo "Already up to date!"
        return 0
    fi

    # Get remote version
    local remote_version="unknown"
    remote_version="$(git show origin/${current_branch}:VERSION 2>/dev/null | tr -d '[:space:]')" && [[ -n "$remote_version" ]] || remote_version="unknown"

    echo "Update available: ${remote_version}"
    echo ""

    if [[ "$check_only" == true ]]; then
        echo "Run 'kit update' to install the update."
        return 0
    fi

    # Ask for confirmation
    read "response?Update to version ${remote_version}? (Y/n): "
    if [[ "$response" =~ ^[Nn]$ ]]; then
        echo "Update cancelled."
        return 0
    fi

    echo ""
    echo "Updating..."

    # Pull latest changes
    if git pull -q; then
        echo "Successfully updated to version ${remote_version}"

        # Check if VERSION changed
        if [[ "$current_version" != "$remote_version" ]]; then
            echo ""
            echo "A new version (${remote_version}) is installed."
            echo ""
            echo "To complete the update, reload your shell:"
            echo "  1. Open a new terminal window, or"
            echo "  2. Run: source ~/.zshrc"
            echo ""
            echo "Or restart your terminal."
        fi

        return 0
    else
        echo "Error: Update failed." >&2
        echo "You may need to resolve merge conflicts or network issues." >&2
        return 1
    fi
}
