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

# Check for optional dependencies
echo ""
print_info "Checking optional dependencies..."

# Source shared package manager detection functions from deps.sh
if [[ -f "$KIT_DIR/functions/deps.sh" ]]; then
    source "$KIT_DIR/functions/deps.sh"

    # Create wrapper functions to use the internal functions from deps.sh
    detect_package_manager() {
        _kit_detect_package_manager
    }

    get_install_cmd() {
        local pkg="$1"
        _kit_get_package_install_cmd "$pkg"
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
fi

check_dependency() {
    local cmd="$1"
    local pkg="$2"
    local category="$3"

    if command -v "$cmd" &> /dev/null; then
        print_success "$cmd installed (for $category)"
        return 0
    else
        print_warning "$cmd not found (needed for $category)"
        local install_cmd
        install_cmd=$(get_install_cmd "$pkg")
        # Check if output doesn't start with "Error"
        if [[ "$install_cmd" != Error:* ]]; then
            echo "   Install with: $install_cmd"
        else
            echo "   $install_cmd"
        fi
        return 1
    fi
}

MISSING_DEPS=()

check_dependency "magick" "imagemagick" "Image Processing" || MISSING_DEPS+=("imagemagick")
check_dependency "yt-dlp" "yt-dlp" "Media Processing" || MISSING_DEPS+=("yt-dlp")
check_dependency "ffmpeg" "ffmpeg" "Media Processing" || MISSING_DEPS+=("ffmpeg")
check_dependency "lsd" "lsd" "Enhanced File Listing" || MISSING_DEPS+=("lsd")

# Offer to install missing dependencies
if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    echo ""
    print_info "Missing optional dependencies: ${MISSING_DEPS[*]}"

    local pm="$(detect_package_manager)"
    if [[ "$pm" != "none" ]]; then
        echo ""
        read "response?Install missing dependencies? (y/N): "
        if [[ "$response" =~ ^[Yy]$ ]]; then
            print_info "Installing dependencies..."
            for dep in "${MISSING_DEPS[@]}"; do
                local install_cmd
                install_cmd=$(get_install_cmd "$dep")
                if eval "$install_cmd"; then
                    print_success "$dep installed"
                else
                    print_error "Failed to install $dep"
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
