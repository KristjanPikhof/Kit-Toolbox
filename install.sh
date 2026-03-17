#!/usr/bin/env zsh
# Kit's Toolkit Installation Script
# Installs kit-toolkit and configures your shell

set -e

# Read version from VERSION file
SCRIPT_DIR="${0:A:h}"
VERSION_FILE="$SCRIPT_DIR/VERSION"
if [[ -f "$VERSION_FILE" ]]; then
    KIT_VERSION="$(cat "$VERSION_FILE" | tr -d '[:space:]')"
else
    KIT_VERSION="unknown"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_success() { echo "${GREEN}✓${NC} $1"; }
print_error() { echo "${RED}✗${NC} $1" >&2; }
print_warning() { echo "${YELLOW}⚠${NC} $1"; }
print_info() { echo "${BLUE}ℹ${NC} $1"; }

# Get the directory where this script is located
KIT_DIR="$SCRIPT_DIR"

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║  Kit's Toolkit $KIT_VERSION - Installation ║"
echo "╚═══════════════════════════════════════╝"
echo ""

# Check if running in zsh
if [[ -z "$ZSH_VERSION" ]]; then
    print_error "This script must be run with zsh"
    echo "Please run: zsh install.sh"
    exit 1
fi

print_success "Running in zsh"

# Detect shell configuration file
if [[ -f "$HOME/.zshrc" ]]; then
    ZSHRC="$HOME/.zshrc"
    print_success "Found .zshrc at $ZSHRC"
else
    print_warning ".zshrc not found, will create it"
    ZSHRC="$HOME/.zshrc"
fi

# Check if already installed
if grep -q "KIT_EXT_DIR" "$ZSHRC" 2>/dev/null; then
    echo ""
    print_warning "Kit appears to already be installed in your .zshrc"
    echo ""
    read "response?Do you want to reinstall/update? (y/N): "
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
fi

# Create backup of .zshrc
if [[ -f "$ZSHRC" ]]; then
    BACKUP="$ZSHRC.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$ZSHRC" "$BACKUP"
    print_success "Created backup: $BACKUP"
fi

# Add kit configuration to .zshrc
echo ""
print_info "Adding Kit configuration to .zshrc..."

# Remove old kit configuration if exists (version-agnostic)
# Matches any "# Kit <version> - Shell Toolkit" marker
if grep -q "# Kit.*- Shell Toolkit" "$ZSHRC" 2>/dev/null; then
    # Use awk for cross-platform compatibility
    # Use index() for literal string matching to avoid regex metacharacter issues
    awk '
        BEGIN { in_kit_block = 0 }
        index($0, "# Kit") == 1 && /Shell Toolkit/ { in_kit_block = 1; next }
        in_kit_block && /loader\.zsh/ { in_kit_block = 0; next }
        !in_kit_block { print }
    ' "$ZSHRC" > "$ZSHRC.tmp"
    mv "$ZSHRC.tmp" "$ZSHRC"
    print_info "Removed old Kit configuration"
fi

# Add new configuration with version from VERSION file
cat >> "$ZSHRC" << EOF

# Kit ${KIT_VERSION} - Shell Toolkit
export KIT_EXT_DIR="$KIT_DIR"
source "\$KIT_EXT_DIR/loader.zsh"
EOF

print_success "Added Kit configuration to .zshrc"

# Check toolkit dependencies
echo ""
print_info "Checking toolkit dependencies..."

# Source shared dependency helpers from deps.sh
if [[ -f "$KIT_DIR/functions/deps.sh" ]]; then
    source "$KIT_DIR/functions/deps.sh"

    detect_package_manager() {
        _kit_detect_package_manager
    }

    get_install_cmd() {
        local pkg="$1"
        _kit_get_package_install_cmd "$pkg"
    }

    get_package_name() {
        local category="$1"
        _kit_get_package_name "$category"
    }

    get_dependency_status() {
        local category="$1"
        local check_cmd="$2"
        _kit_get_dependency_status "$category" "$check_cmd"
    }

    list_dependencies() {
        _kit_get_dependencies
    }
else
    # Fallback functions if deps.sh is not available
    detect_package_manager() {
        case "$(uname -s)" in
            Darwin)
                if command -v brew &> /dev/null; then
                    echo "brew"
                else
                    echo "none"
                fi
                ;;
            Linux)
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

    get_install_cmd() {
        local pkg="$1"
        local pm="$(detect_package_manager)"
        local os="$(uname -s)"

        case "$pm" in
            brew)
                echo "brew install $pkg"
                ;;
            apt)
                echo "sudo apt update && sudo apt install -y $pkg"
                ;;
            dnf)
                echo "sudo dnf install -y $pkg"
                ;;
            yum)
                echo "sudo yum install -y $pkg"
                ;;
            pacman)
                echo "sudo pacman -S --noconfirm $pkg"
                ;;
            zypper)
                echo "sudo zypper install -y $pkg"
                ;;
            none)
                case "$os" in
                    Darwin)
                        echo "Error: Homebrew not found."
                        echo "Install with: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
                        echo "See: https://brew.sh"
                        ;;
                    Linux)
                        echo "Error: No supported package manager found (apt, dnf, yum, pacman, zypper)"
                        ;;
                esac
                return 1
                ;;
        esac
    }

    get_package_name() {
        local category="$1"
        echo "$category"
    }

    get_dependency_status() {
        local category="$1"
        local check_cmd="$2"

        if eval "$check_cmd" &> /dev/null; then
            echo "installed"
        else
            echo "missing"
        fi
    }

    list_dependencies() {
        cat << 'EOF'
imagemagick|command -v magick|imagemagick|ImageMagick v7+ for image processing
yt-dlp|command -v yt-dlp|yt-dlp|YouTube/media downloader
ffmpeg|command -v ffmpeg|ffmpeg|Video/audio processing
qpdf|command -v qpdf|qpdf|PDF transformation and optimization toolkit
lsd|command -v lsd|lsd|Enhanced file listing
lsof|command -v lsof|lsof|List open files (for killports)
EOF
    }
fi

print_dependency_status() {
    local category="$1"
    local package_name="$2"
    local description="$3"
    local dep_state="$4"

    case "$dep_state" in
        installed)
            print_success "$package_name installed ($description)"
            return 0
            ;;
        legacy_v6)
            print_warning "ImageMagick v6 detected ($description)"
            echo "   Upgrade to v7+ with the 'magick' command."
            if declare -f _kit_imagemagick_install_help > /dev/null 2>&1; then
                _kit_imagemagick_install_help "upgrade"
            fi
            return 1
            ;;
        missing_magick)
            print_warning "ImageMagick detected, but 'magick' is missing ($description)"
            echo "   Reinstall or fix PATH so the v7 CLI is available."
            if declare -f _kit_imagemagick_install_help > /dev/null 2>&1; then
                _kit_imagemagick_install_help "upgrade"
            fi
            return 1
            ;;
        *)
            print_warning "$package_name not found ($description)"
            local install_cmd
            install_cmd=$(get_install_cmd "$package_name")
            if [[ "$install_cmd" != Error:* ]]; then
                echo "   Install with: $install_cmd"
            else
                echo "   $install_cmd"
            fi
            return 1
            ;;
    esac
}

ACTION_DEPS=()

while IFS='|' read -r category check_cmd package_name description; do
    [[ -z "$category" ]] && continue

    dep_state=$(get_dependency_status "$category" "$check_cmd")
    actual_pkg_name=$(get_package_name "$category")

    if ! print_dependency_status "$category" "$actual_pkg_name" "$description" "$dep_state"; then
        ACTION_DEPS+=("$category|$actual_pkg_name|$dep_state")
    fi
done < <(list_dependencies)

# Offer to install missing or unsupported dependencies
if [[ ${#ACTION_DEPS[@]} -gt 0 ]]; then
    echo ""
    print_info "Dependencies needing action:"
    for dep in "${ACTION_DEPS[@]}"; do
        pkg_name="${dep#*|}"
        pkg_name="${pkg_name%%|*}"
        echo "  - $pkg_name"
    done

    pm="$(detect_package_manager)"
    needs_imagemagick_ppa=false
    if [[ "$pm" == "apt" ]]; then
        for dep in "${ACTION_DEPS[@]}"; do
            dep_category="${dep%%|*}"
            if [[ "$dep_category" == "imagemagick" ]]; then
                needs_imagemagick_ppa=true
                break
            fi
        done
    fi

    if [[ "$needs_imagemagick_ppa" == "true" ]]; then
        echo ""
        print_warning "ImageMagick v7 is required for image functions."
        echo "   On Ubuntu/Debian, you may need to add the official PPA first:"
        echo "   sudo add-apt-repository ppa:imagemagick/ppa"
        echo "   sudo apt update"
    fi

    if [[ "$pm" != "none" ]]; then
        echo ""
        read "response?Install or upgrade these dependencies? (y/N): "
        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_info "Installing dependencies..."
            for dep in "${ACTION_DEPS[@]}"; do
                dep_rest="${dep#*|}"
                pkg_name="${dep_rest%%|*}"
                install_cmd=$(get_install_cmd "$pkg_name")
                if eval "$install_cmd"; then
                    print_success "$pkg_name installed"
                else
                    print_error "Failed to install $pkg_name"
                fi
            done
            print_success "Dependency installation complete"
        fi
    else
        print_warning "No supported package manager found."
        if [[ "$(uname -s)" == "Darwin" ]]; then
            print_info "Install Homebrew: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
            print_info "Then run: kit deps-install"
        else
            print_info "Install a package manager (apt, dnf, yum, pacman, zypper) then run: kit deps-install"
        fi
    fi
fi

# Setup shortcuts.conf
echo ""
print_info "Setting up navigation shortcuts..."

if [[ -f "$KIT_DIR/shortcuts.conf" ]]; then
    print_success "shortcuts.conf already exists"
else
    if [[ -f "$KIT_DIR/shortcuts.conf.example" ]]; then
        cp "$KIT_DIR/shortcuts.conf.example" "$KIT_DIR/shortcuts.conf"
        print_success "Created shortcuts.conf from example"
        print_info "Customize your shortcuts in: $KIT_DIR/shortcuts.conf"
    else
        # Create a basic shortcuts.conf
        cat > "$KIT_DIR/shortcuts.conf" << 'EOF'
# shortcuts.conf - Directory shortcuts for quick navigation
# Format: shortcut_name|full_path|description
#
# Fields (pipe-separated):
# 1. Shortcut name (used with: kit <name>)
# 2. Full path (can use ~ for home directory)
# 3. Description

# Example shortcuts (customize these for your needs)
# dev|~/Development|Main development directory
# docs|~/Documents|Documents folder
# downloads|~/Downloads|Downloads folder
EOF
        print_success "Created basic shortcuts.conf"
        print_info "Add your shortcuts to: $KIT_DIR/shortcuts.conf"
        print_info "Format: name|path|description"
    fi
fi

# Verify installation
echo ""
print_info "Verifying installation..."

# Source the loader to test
if source "$KIT_DIR/loader.zsh" 2>/dev/null; then
    print_success "Kit loader loaded successfully"

    # Test kit command
    if declare -f kit > /dev/null 2>&1; then
        print_success "Kit command is available"
    else
        print_error "Kit command not found after loading"
    fi
else
    print_error "Failed to load Kit"
    exit 1
fi

# Installation complete
echo ""
echo "╔═══════════════════════════════════════╗"
echo "║     Installation Complete! 🎉        ║"
echo "╚═══════════════════════════════════════╝"
echo ""
print_info "To start using Kit, either:"
echo "  1. Open a new terminal window, or"
echo "  2. Run: ${BLUE}source ~/.zshrc${NC}"
echo ""
print_info "Get started with:"
echo "  ${BLUE}kit -h${NC}              # Show all available functions"
echo "  ${BLUE}kit <function> -h${NC}   # Show help for specific function"
echo "  ${BLUE}kit --search <term>${NC} # Search for functions"
echo ""
print_info "Documentation: $KIT_DIR/README.md"
echo ""
