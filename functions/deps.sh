# deps.sh - Dependency management utilities
# Category: Dependencies
# Description: Cross-platform dependency detection and installation
# Dependencies: none (uses system package managers)
# Functions: deps-install, deps-check

# Detect the operating system
_kit_detect_os() {
    case "$(uname -s)" in
        Darwin)  echo "macos" ;;
        Linux)   echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

# Detect available package manager
# Returns: brew, apt, dnf, pacman, yum, zypper, or none
_kit_detect_package_manager() {
    local os="$(_kit_detect_os)"

    case "$os" in
        macos)
            if command -v brew &> /dev/null; then
                echo "brew"
            else
                echo "none"
            fi
            ;;
        linux)
            if command -v apt &> /dev/null; then
                echo "apt"
            elif command -v dnf &> /dev/null; then
                echo "dnf"
            elif command -v yum &> /dev/null; then
                echo "yum"
            elif command -v pacman &> /dev/null; then
                echo "pacman"
            elif command -v zypper &> /dev/null; then
                echo "zypper"
            else
                echo "none"
            fi
            ;;
        *)
            echo "none"
            ;;
    esac
}

# Get install command for a package based on current system
_kit_get_package_install_cmd() {
    local pkg_name="$1"
    local pm="$(_kit_detect_package_manager)"
    local os="$(_kit_detect_os)"

    case "$pm" in
        brew)
            echo "brew install $pkg_name"
            ;;
        apt)
            echo "sudo apt update && sudo apt install -y $pkg_name"
            ;;
        dnf)
            echo "sudo dnf install -y $pkg_name"
            ;;
        yum)
            echo "sudo yum install -y $pkg_name"
            ;;
        pacman)
            echo "sudo pacman -S --noconfirm $pkg_name"
            ;;
        zypper)
            echo "sudo zypper install -y $pkg_name"
            ;;
        none)
            case "$os" in
                macos)
                    echo "Error: Homebrew not found. Install from https://brew.sh then: brew install $pkg_name"
                    ;;
                linux)
                    echo "Error: No supported package manager found. Please install $pkg_name manually."
                    ;;
                *)
                    echo "Error: Unsupported OS. Please install $pkg_name manually."
                    ;;
            esac
            return 1
            ;;
    esac
}

# Package name mapping for different systems
# Some packages have different names across package managers
_kit_get_package_name() {
    local category="$1"
    local pm="$(_kit_detect_package_manager)"

    case "$category" in
        imagemagick)
            # ImageMagick package name varies by distro
            case "$pm" in
                apt) echo "imagemagick" ;;
                dnf|yum) echo "ImageMagick" ;;
                pacman) echo "imagemagick" ;;
                zypper) echo "ImageMagick" ;;
                brew) echo "imagemagick" ;;
                *) echo "imagemagick" ;;
            esac
            ;;
        lsd)
            # lsd package name
            case "$pm" in
                apt) echo "lsd" ;;
                dnf|yum) echo "lsd" ;;
                pacman) echo "lsd" ;;
                zypper) echo "lsd" ;;
                brew) echo "lsd" ;;
                *) echo "lsd" ;;
            esac
            ;;
        *)
            # Most packages have the same name
            echo "$category"
            ;;
    esac
}

# Define all Kit dependencies with their check commands
# Format: "category|check_command|package_name|description"
_kit_get_dependencies() {
    cat << 'EOF'
imagemagick|command -v magick|imagemagick|ImageMagick v7+ for image processing
yt-dlp|command -v yt-dlp|yt-dlp|YouTube/media downloader
ffmpeg|command -v ffmpeg|ffmpeg|Video/audio processing
qpdf|command -v qpdf|qpdf|PDF transformation and optimization toolkit
lsd|command -v lsd|lsd|Enhanced file listing
lsof|command -v lsof|lsof|List open files (for killports)
EOF
}

# Check if a dependency is installed
_kit_check_dependency() {
    local check_cmd="$1"
    eval "$check_cmd" &> /dev/null
}

# Helper function to print ImageMagick installation instructions
# Usage: _kit_imagemagick_install_help <mode>
#   mode: "install" or "upgrade"
_kit_imagemagick_install_help() {
    local mode="$1"
    local action="install"

    if [[ "$mode" == "upgrade" ]]; then
        action="upgrade"
    fi

    case "$(uname -s)" in
        Darwin)
            if [[ "$mode" == "upgrade" ]]; then
                echo "  brew $action imagemagick" >&2
                echo "  # If that doesn't work, try:" >&2
                echo "  brew reinstall imagemagick" >&2
            else
                echo "  brew $action imagemagick" >&2
            fi
            ;;
        Linux)
            echo "  # Ubuntu/Debian - add official PPA for v7:" >&2
            echo "  sudo add-apt-repository ppa:imagemagick/ppa" >&2
            if [[ "$mode" == "upgrade" ]]; then
                echo "  sudo apt update" >&2
                echo "  sudo apt $action imagemagick" >&2
            else
                echo "  sudo apt update && sudo apt $action imagemagick" >&2
            fi
            echo "" >&2
            echo "  # Fedora:" >&2
            echo "  sudo dnf $action ImageMagick" >&2
            echo "" >&2
            echo "  # Arch:" >&2
            echo "  sudo pacman -S imagemagick" >&2
            ;;
        *)
            echo "  See: https://imagemagick.org/script/download.php" >&2
            ;;
    esac
}

_kit_get_imagemagick_version_line() {
    if command -v magick &> /dev/null; then
        magick --version 2>/dev/null | head -1
        return 0
    fi

    if command -v convert &> /dev/null; then
        convert --version 2>/dev/null | head -1
        return 0
    fi

    return 1
}

# Prefer the modern `magick` CLI. If only `convert` exists, inspect its version
# so we can distinguish legacy ImageMagick 6 from a broken ImageMagick 7 install.
_kit_get_imagemagick_status() {
    if command -v magick &> /dev/null; then
        echo "installed"
        return 0
    fi

    if command -v convert &> /dev/null; then
        local version_line
        version_line=$(convert --version 2>/dev/null | head -1)
        if [[ "$version_line" == *"ImageMagick 7."* ]]; then
            echo "missing_magick"
        else
            echo "legacy_v6"
        fi
        return 0
    fi

    echo "missing"
}

_kit_get_dependency_status() {
    local category="$1"
    local check_cmd="$2"

    case "$category" in
        imagemagick)
            _kit_get_imagemagick_status
            ;;
        *)
            if _kit_check_dependency "$check_cmd"; then
                echo "installed"
            else
                echo "missing"
            fi
            ;;
    esac
}

# Require ImageMagick v7+ via the `magick` command. Older v6 installs still ship
# `convert`, but Kit uses `magick` everywhere, so v6 must be treated as unsupported.
_kit_require_imagemagick() {
    local im_status
    im_status=$(_kit_get_imagemagick_status)

    case "$im_status" in
        installed)
            return 0
            ;;
        legacy_v6)
            local version_line
            version_line=$(_kit_get_imagemagick_version_line)
            echo "Error: ImageMagick v6 detected. Kit requires ImageMagick v7+." >&2
            echo "" >&2
            if [[ -n "$version_line" ]]; then
                echo "Detected: $version_line" >&2
            fi
            echo "Kit's image functions require the 'magick' command from v7+." >&2
            echo "" >&2
            echo "Upgrade instructions:" >&2
            _kit_imagemagick_install_help "upgrade"
            return 1
            ;;
        missing_magick)
            local version_line
            version_line=$(_kit_get_imagemagick_version_line)
            echo "Error: ImageMagick detected, but the 'magick' command is not available." >&2
            echo "" >&2
            if [[ -n "$version_line" ]]; then
                echo "Detected: $version_line" >&2
            fi
            echo "Kit prioritizes the modern ImageMagick CLI and requires 'magick' on PATH." >&2
            echo "" >&2
            echo "Reinstall or fix PATH so 'magick' is available:" >&2
            _kit_imagemagick_install_help "upgrade"
            return 1
            ;;
        *)
            echo "Error: ImageMagick not found. Install v7+ for image functions." >&2
            echo "" >&2
            echo "Install with:" >&2
            _kit_imagemagick_install_help "install"
            return 1
            ;;
    esac
}

# Require a tool to be installed, or print cross-platform install instructions and return 1
# Usage: _kit_require <command> [package_name]
#   command      - The command to check (e.g., ffmpeg, qpdf, lsd)
#   package_name - Optional package name if different from command (e.g., "imagemagick" for "magick")
_kit_require() {
    local cmd="$1"
    local pkg="${2:-$1}"

    if [[ "$cmd" == "magick" || "$pkg" == "imagemagick" ]]; then
        _kit_require_imagemagick
        return $?
    fi

    if command -v "$cmd" &> /dev/null; then
        return 0
    fi

    echo "Error: $cmd not installed." >&2
    local install_cmd
    install_cmd=$(_kit_get_package_install_cmd "$(_kit_get_package_name "$pkg")")
    if [[ "$install_cmd" != Error:* ]]; then
        echo "Install with: $install_cmd" >&2
    else
        echo "$install_cmd" >&2
    fi
    return 1
}

# Check all dependencies and show status
deps-check() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit deps-check
Description: Check status of all Kit toolkit dependencies
Examples:
  kit deps-check
EOF
        return 0
    fi

    local pm="$(_kit_detect_package_manager)"
    local os="$(_kit_detect_os)"

    echo ""
    echo "Kit's Toolkit - Dependency Status"
    echo "=================================="
    echo "OS: $os"
    echo "Package Manager: $pm"
    echo ""

    local installed_count=0
    local unsupported_count=0
    local missing_count=0

    while IFS='|' read -r category check_cmd package_name description; do
        # Skip empty lines
        [[ -z "$category" ]] && continue

        case "$(_kit_get_dependency_status "$category" "$check_cmd")" in
            installed)
                echo "✓ $package_name - $description"
                ((installed_count++))
                ;;
            legacy_v6)
                echo "⚠️  $package_name - ImageMagick v6 detected; upgrade to v7+ with 'magick'"
                ((unsupported_count++))
                ;;
            missing_magick)
                echo "⚠️  $package_name - ImageMagick detected, but 'magick' is missing from PATH"
                ((unsupported_count++))
                ;;
            *)
                echo "✗ $package_name - $description"
                ((missing_count++))
                ;;
        esac
    done < <(_kit_get_dependencies)

    echo ""
    echo "Summary: $installed_count installed, $unsupported_count unsupported, $missing_count missing"
    echo ""

    if [[ $unsupported_count -gt 0 || $missing_count -gt 0 ]]; then
        echo "Install or upgrade dependencies with:"
        echo "  kit deps-install"
        echo ""
        return 1
    fi

    return 0
}

# Install all missing dependencies
deps-install() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit deps-install [options]
Description: Install missing dependencies for your platform
Options:
  --dry-run    Show what would be installed without installing
  --yes        Auto-confirm all prompts (skip confirmation)
Examples:
  kit deps-install
  kit deps-install --dry-run
  kit deps-install --yes
EOF
        return 0
    fi

    local dry_run=false
    local auto_confirm=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            --yes)
                auto_confirm=true
                shift
                ;;
            *)
                echo "Error: Unknown option '$1'" >&2
                return 2
                ;;
        esac
    done

    local pm="$(_kit_detect_package_manager)"
    local os="$(_kit_detect_os)"

    # Check if package manager is available
    if [[ "$pm" == "none" ]]; then
        case "$os" in
            macos)
                echo "Error: No package manager found." >&2
                echo "" >&2
                echo "On macOS, you need Homebrew:" >&2
                echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"" >&2
                echo "" >&2
                echo "See https://brew.sh for details." >&2
                ;;
            linux)
                echo "Error: No supported package manager found." >&2
                echo "" >&2
                echo "Supported package managers: apt, dnf, yum, pacman, zypper" >&2
                echo "" >&2
                echo "Please install one manually for your Linux distribution." >&2
                ;;
            *)
                echo "Error: Unsupported operating system: $os" >&2
                ;;
        esac
        return 1
    fi

    echo ""
    echo "Kit's Toolkit - Dependency Installer"
    echo "===================================="
    echo "OS: $os"
    echo "Package Manager: $pm"
    echo ""

    # Build list of missing dependencies
    local action_required_deps=()
    local action_required_count=0

    while IFS='|' read -r category check_cmd package_name description; do
        # Skip empty lines
        [[ -z "$category" ]] && continue

        local dep_state
        dep_state=$(_kit_get_dependency_status "$category" "$check_cmd")

        if [[ "$dep_state" != "installed" ]]; then
            local actual_pkg_name
            actual_pkg_name=$(_kit_get_package_name "$category")
            action_required_deps+=("$actual_pkg_name|$description|$dep_state")
            ((action_required_count++))
        fi
    done < <(_kit_get_dependencies)

    if [[ $action_required_count -eq 0 ]]; then
        echo "✓ All dependencies are already installed!"
        echo ""
        return 0
    fi

    echo "Found $action_required_count dependencies needing action:"
    echo ""
    for dep in "${action_required_deps[@]}"; do
        local pkg_name="${dep%%|*}"
        local rest="${dep#*|}"
        local desc="${rest%%|*}"
        local dep_state="${dep##*|}"

        case "$dep_state" in
            legacy_v6)
                echo "  • $pkg_name - $desc (legacy v6 detected; upgrade required)"
                ;;
            missing_magick)
                echo "  • $pkg_name - $desc ('magick' command missing; reinstall/fix PATH)"
                ;;
            *)
                echo "  • $pkg_name - $desc"
                ;;
        esac
    done
    echo ""

    # Special handling for ImageMagick on Ubuntu/Debian
    local pm_needs_imagemagick_ppa=false
    if [[ "$pm" == "apt" ]]; then
        for dep in "${action_required_deps[@]}"; do
            local pkg_name="${dep%%|*}"
            if [[ "$pkg_name" == "imagemagick" ]]; then
                pm_needs_imagemagick_ppa=true
                break
            fi
        done
    fi

    if [[ "$pm_needs_imagemagick_ppa" == "true" ]]; then
        echo "⚠️  Note: ImageMagick v7 is required for image functions." >&2
        echo "   On Ubuntu/Debian, this may require adding a PPA:" >&2
        echo "   sudo add-apt-repository ppa:imagemagick/ppa" >&2
        echo "   sudo apt update" >&2
        echo "" >&2
    fi

    # Dry run mode
    if [[ "$dry_run" == "true" ]]; then
        echo "Commands that would be run:"
        echo ""
        for dep in "${action_required_deps[@]}"; do
            local pkg_name="${dep%%|*}"
            local install_cmd
            install_cmd=$(_kit_get_package_install_cmd "$pkg_name")
            # Check if output doesn't start with "Error"
            if [[ "$install_cmd" != Error:* ]]; then
                echo "  $install_cmd"
            fi
        done
        echo ""
        echo "Dry run complete. No changes made."
        echo ""
        return 0
    fi

    # Confirm installation
    if [[ "$auto_confirm" != "true" ]]; then
        echo "Install or upgrade these dependencies? (y/N):"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            return 0
        fi
    fi

    # Install dependencies
    echo ""
    echo "Installing dependencies..."
    echo ""

    local success_count=0
    local fail_count=0

    for dep in "${action_required_deps[@]}"; do
        local pkg_name="${dep%%|*}"
        local rest="${dep#*|}"
        local desc="${rest%%|*}"

        echo "→ Installing $pkg_name..."

        # Get install command
        local install_cmd
        install_cmd=$(_kit_get_package_install_cmd "$pkg_name")

        # Check if output starts with "Error"
        if [[ "$install_cmd" == Error:* ]]; then
            echo "  $install_cmd" >&2
            ((fail_count++))
            continue
        fi

        # Run install command
        if eval "$install_cmd" 2>&1; then
            echo "  ✓ $pkg_name installed"
            ((success_count++))
        else
            echo "  ✗ Failed to install $pkg_name" >&2
            ((fail_count++))
        fi
        echo ""
    done

    echo "Installation complete!"
    echo "Success: $success_count, Failed: $fail_count"
    echo ""

    # Verify ImageMagick v7 specifically
    local imagemagick_status
    imagemagick_status=$(_kit_get_imagemagick_status)
    case "$imagemagick_status" in
        installed)
            local magick_version
            magick_version=$(_kit_get_imagemagick_version_line)
            echo "✓ ImageMagick: $magick_version"
            ;;
        legacy_v6)
            echo "⚠️  Warning: ImageMagick v6 detected after install." >&2
            echo "   Image functions require v7+ with 'magick' command." >&2
            echo "   Upgrade with:" >&2
            _kit_imagemagick_install_help "upgrade"
            echo ""
            ;;
        missing_magick)
            echo "⚠️  Warning: ImageMagick detected, but 'magick' is still missing from PATH." >&2
            echo "   Reinstall or fix PATH so Kit can use the modern CLI." >&2
            echo "   Suggested fix:" >&2
            _kit_imagemagick_install_help "upgrade"
            echo ""
            ;;
    esac

    return 0
}
