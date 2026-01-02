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
lsd|command -v lsd|lsd|Enhanced file listing
lsof|command -v lsof|lsof|List open files (for killports)
EOF
}

# Check if a dependency is installed
_kit_check_dependency() {
    local check_cmd="$1"
    eval "$check_cmd" &> /dev/null
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
    local missing_count=0

    while IFS='|' read -r category check_cmd package_name description; do
        # Skip empty lines
        [[ -z "$category" ]] && continue

        if _kit_check_dependency "$check_cmd"; then
            echo "✓ $package_name - $description"
            ((installed_count++))
        else
            echo "✗ $package_name - $description"
            ((missing_count++))
        fi
    done < <(_kit_get_dependencies)

    echo ""
    echo "Summary: $installed_count installed, $missing_count missing"
    echo ""

    if [[ $missing_count -gt 0 ]]; then
        echo "Install missing dependencies with:"
        echo "  kit deps-install"
        echo ""
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
    local missing_deps=()
    local missing_count=0

    while IFS='|' read -r category check_cmd package_name description; do
        # Skip empty lines
        [[ -z "$category" ]] && continue

        if ! _kit_check_dependency "$check_cmd"; then
            local actual_pkg_name
            actual_pkg_name=$(_kit_get_package_name "$category")
            missing_deps+=("$actual_pkg_name|$description")
            ((missing_count++))
        fi
    done < <(_kit_get_dependencies)

    if [[ $missing_count -eq 0 ]]; then
        echo "✓ All dependencies are already installed!"
        echo ""
        return 0
    fi

    echo "Found $missing_count missing dependencies:"
    echo ""
    for dep in "${missing_deps[@]}"; do
        local pkg_name="${dep%%|*}"
        local desc="${dep##*|}"
        echo "  • $pkg_name - $desc"
    done
    echo ""

    # Special handling for ImageMagick on Ubuntu/Debian
    local pm_needs_imagemagick_ppa=false
    if [[ "$pm" == "apt" ]]; then
        for dep in "${missing_deps[@]}"; do
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
        for dep in "${missing_deps[@]}"; do
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
        echo "Install missing dependencies? (y/N):"
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

    for dep in "${missing_deps[@]}"; do
        local pkg_name="${dep%%|*}"
        local desc="${dep##*|}"

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
    if command -v magick &> /dev/null; then
        local magick_version
        magick_version=$(magick --version 2>/dev/null | head -1)
        echo "✓ ImageMagick: $magick_version"
    elif command -v convert &> /dev/null; then
        echo "⚠️  Warning: ImageMagick v6 detected (convert command found)." >&2
        echo "   Image functions require v7+ with 'magick' command." >&2
        echo "   On Ubuntu/Debian:" >&2
        echo "     sudo add-apt-repository ppa:imagemagick/ppa" >&2
        echo "     sudo apt update && sudo apt install imagemagick" >&2
        echo ""
    fi

    return 0
}
