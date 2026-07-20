# Kit's Toolkit v2.9.0

A modular, extensible shell function toolkit for macOS/Linux with auto-discovery, tab completion, and AI-friendly development patterns.

## Platform Support

**macOS & Linux | Zsh Only**

This toolkit is designed to work on both macOS and Linux, but **requires the Zsh shell**.

### Shell Requirements

| Requirement | Status |
|-------------|--------|
| **Zsh** | ✅ Required (version 5.0+) |
| Bash | ❌ Not supported |

**Why Zsh only?**
- The toolkit uses Zsh-specific features like arrays (`${(f)var}`), parameter expansion (`${${(%):-%x}:A:h}`), and completion system (`compdef`)
- The loader (`loader.zsh`) and completion scripts use Zsh-specific syntax
- Installing for Bash would require a separate loader and completion system

### OS Support

| OS | Status |
|----|--------|
| **macOS** | ✅ Fully supported |
| **Linux** | ✅ Fully supported (Debian/Ubuntu, Fedora, Arch, openSUSE) |

Image functions require **ImageMagick v7+** (with the `magick` command).

## Features

✨ **Modular Design**
Functions organized by category (images, media, system, navigation, etc.). Each category is a self-contained shell module.

🎯 **Discoverability**
Built-in help system with `kit -h` shows all functions grouped by category. Search functions with `kit --search <keyword>`.

⚡ **Dynamic Tab Completion**
Auto-discovering tab completion for functions, editors, and shortcuts. No manual regeneration needed!

🤖 **AI-Friendly**
Clear development patterns, template generator, and validator make it easy for AI agents (and humans) to add new functions consistently.

📚 **Comprehensive Help**
Every function has built-in help: `kit my-function -h`

## Quick Start

### Prerequisites

**You must be using Zsh as your shell.** To check:

```bash
echo $SHELL  # Should show /bin/zsh or /usr/bin/zsh
echo $ZSH_VERSION  # Should show a version number
```

If you're using Bash but want to switch to Zsh:

```bash
# macOS (default is already Zsh on modern macOS)
# Just open a new terminal

# Linux
sudo apt install zsh  # Debian/Ubuntu
sudo dnf install zsh  # Fedora
sudo pacman -S zsh    # Arch

# Then change your default shell
chsh -s $(which zsh)
# Log out and back in for changes to take effect
```

### Installation

#### Automated Installation (Recommended)

```bash
# Clone kit-toolkit to ANY directory you prefer
git clone https://github.com/KristjanPikhof/Kit-Toolbox.git

# Run the install script (it will auto-detect its location)
zsh install.sh
```

**Note:** The installer automatically detects where you've downloaded kit-toolkit, so it works from any location.

The installer will:
- ✓ Backup your existing `.zshrc`
- ✓ Add Kit configuration to your shell
- ✓ Detect your OS and package manager (macOS/Linux with brew, apt, dnf, pacman, etc.)
- ✓ Check for optional dependencies (ImageMagick, yt-dlp, ffmpeg, lsd)
- ✓ Offer to install missing dependencies automatically
- ✓ Verify the installation

#### Manual Installation

If you prefer to install manually:

```bash
# Add to your ~/.zshrc (replace /path/to with your actual location)
export KIT_EXT_DIR="/path/to/kit-toolkit"
source "$KIT_EXT_DIR/loader.zsh"

# Then reload your shell
source ~/.zshrc
```

**Tip:** Use the automated installer - it automatically detects the correct path!

### Usage

```bash
# List all functions
kit -h

# Get help for a specific function
kit img-resize -h

# Search for functions
kit --search resize
kit --list-categories

# Run a function
kit img-resize 800x600 myimage.jpg
kit yt-download mp3 "https://youtube.com/watch?v=..."
```

## Available Functions

### 📷 Image Processing
Process images using ImageMagick:
- **img-rename** — Sanitize image filenames or rename sequentially. Features: custom separators (`_` or `-`), sequential naming with `--name`, recursive processing (`-r`), and dry-run mode (`-n`).
- **img-resize** — Resize image preserving aspect ratio
- **img-resize-width** — Resize image to specific width (auto height)
- **img-resize-percentage** — Resize image by percentage (for upscaling/downscaling)
- **img-optimize** — Strip metadata and recompress without changing format
- **img-convert** — Batch convert image formats
- **img-optimize-to-webp** — Convert a single image or directory of images to optimized WebP
- **img-thumbnail** — Fast thumbnail generation
- **img-resize-exact** — Force exact dimensions (may distort)
- **img-resize-fill** — Resize to fill area, crop excess
- **img-adaptive-resize** — Quality resize with mesh interpolation
- **img-batch-resize** — Batch resize multiple images
- **img-resize-shrink-only** — Only shrink images, never enlarge
- **img-resize-colorspace** — Resize with colorspace correction

### 🎬 Media Processing
Download and process video/audio:
- **yt-download** — Download YouTube audio as balanced-quality MP3 or explicitly remux video to MP4
- **remove-audio** — Remove audio with a lossless video stream copy by default
- **convert-to-mp3** — Extract audio using speech, compact, standard, high, or maximum MP3 profiles
- **compress-video** — Compress video with CRF, a no-upscale maximum width, and configurable audio bitrate

### 📄 PDF Processing
Split, merge, compress, and rotate PDF files:
- **pdf-split** — Extract pages using flexible syntax ("2-20", "1,5,19")
- **pdf-burst** — Split PDF into multiple files of fixed page count
- **pdf-merge** — Combine multiple PDFs into one
- **pdf-compress** — Reduce PDF file size
- **pdf-rotate** — Rotate pages 90°, 180°, or 270°

### 🖇️ System Utilities
Shell and filesystem tools:
- **mklink** — Create symbolic links with validation
- **killports** — Kill processes using specified network ports
- **uninstall** — Remove Kit's Toolkit configuration from your shell
- **update** — Update Kit's Toolkit to the latest version

### 📦 Dependencies
Cross-platform dependency management:
- **deps-check** — Check status of all toolkit dependencies
- **deps-install** — Install missing dependencies for your platform (supports macOS/Linux with brew, apt, dnf, pacman, yum, zypper)

### 🧭 Navigation Shortcuts
Auto-generated shortcuts from `shortcuts.conf` for quick directory navigation:

**Auto-generated navigation shortcuts** (configured in `shortcuts.conf`):
```bash
kit dev        # Navigate to ~/Desktop/Development
kit claudedir  # Navigate to ~/.claude/
kit kit        # Navigate to kit-toolkit directory
# ... and more, see `kit -h` for full list
```

Kit also creates direct shell functions for these shortcuts after the loader is sourced, so `dev` and `kit dev` both work unless that name already belongs to another function. If there is a conflict, the existing function wins and Kit prints a warning.

Shortcut wrappers use a source-time registry. Valid shortcut changes are picked up after you reload Kit (`source ~/.zshrc` or `source "$KIT_EXT_DIR/loader.zsh"`). Removed shortcuts are unregistered on re-source. Config edits without re-sourcing keep the previous registry until you reload.

**Deprecated:** `kit goto <name>` is deprecated. Use shortcuts directly: `kit <name>`

### ✏️ Editor Shortcuts
Auto-generated shortcuts from `editor.conf` for opening files/folders in your preferred editor:

```bash
kit code myfile.md    # Open file in VS Code
kit zed .             # Open current folder in Zed
kit cursor src/       # Open folder in Cursor editor
```

**Auto-generated editor shortcuts** (configured in `editor.conf`):

The editor shortcuts are automatically generated from your `editor.conf` file. This file is **user-specific** and **git-ignored**, so you can customize it with your preferred editors.

**Example `editor.conf` entries:**
```bash
# Format: name|command|description
code|code|VS Code
zed|open -a Zed|Zed editor (macOS)
cursor|cursor|Cursor AI editor
nvim|nvim|Neovim
```

Editor commands are parsed safely as command arguments, not evaluated as shell code. Quoted arguments work:

```bash
zed|open -a "Zed"|Zed editor (macOS)
app|/Applications/My\ Editor.app/Contents/MacOS/editor --safe-mode|Custom editor
quoted|fake-editor '--one argument'|Example with a quoted flag value
```

For safety, editor commands do not support shell operators, command substitution, or environment-variable expansion. Use a command on `PATH` or an absolute executable path if the program name contains spaces.

As with navigation shortcuts, Kit creates direct editor functions after the loader is sourced, so `code README.md` and `kit code README.md` both work. Existing functions are not overwritten. Valid editor config changes are picked up after you reload Kit; removed editors are unregistered on re-source.

Create your `editor.conf` from the example:
```bash
cp editor.conf.example editor.conf
```

**Note:** After creating `editor.conf`, reload your shell to see editors in `kit -h`:
```bash
source ~/.zshrc
```

Disable auto-generation of editor shortcuts:
```bash
export KIT_AUTO_EDITORS=false
```

### 📂 File Listing Enhancements
Enhanced file listing with `lsd`:
- **list-files** — List files (newest first)
- **list-all** — List all files including hidden
- **list-reverse** — List files (oldest first)
- **list-all-reverse** — List all files (oldest first)
- **list-tree** — Display tree structure

## Directory Structure

```
kit-toolkit/
├── loader.zsh                # Main loader with kit dispatcher
├── install.sh                # Automated installation script
├── categories.conf           # Category registry
├── shortcuts.conf            # User-specific navigation shortcuts (git-ignored)
├── shortcuts.conf.example    # Example shortcuts template
├── editor.conf               # User-specific editor shortcuts (git-ignored)
├── editor.conf.example       # Example editor shortcuts template
├── .gitignore                # Git ignore rules
├── README.md                 # This file
├── CONTRIBUTING.md           # Guide for adding new functions
│
├── lib/                      # Shared internal helpers
│   └── kit-core.zsh          # Config parsing and validation helpers
│
├── functions/                # Function modules
│   ├── images.sh             # Image processing functions
│   ├── media.sh              # Media processing functions
│   ├── pdf.sh                # PDF processing functions
│   ├── system.sh             # System utilities
│   ├── aliases.sh            # Navigation shortcuts
│   └── lsd.sh                # File listing utilities
│
├── completions/              # Zsh completion scripts
│   └── _kit                  # Tab completion for kit command
│
├── scripts/                  # Development and maintenance tools
│   ├── new-function.sh       # Template generator for new functions
│   ├── validate-pattern.sh   # Validator for pattern compliance
│   ├── generate-completions.sh  # Completion system verifier (system is fully dynamic)
│   ├── validate-shortcuts.sh # Validate shortcuts configuration
│   └── validate-editors.sh   # Validate editor shortcuts configuration
│
├── tests/                    # Test suite
│   ├── run-tests.sh          # Main integration test runner
│   ├── test-kit-core.zsh     # Hermetic kit-core helper tests
│   ├── test-loader-config.zsh # Hermetic shortcut/editor dispatch tests
│   ├── test-discovery-output.zsh # Hermetic help/completion output tests
│   └── test-media.zsh        # Hermetic media conversion contract tests
│
└── llm_prompts/              # AI development guides
    └── kit_pattern.md        # Complete pattern specification
```

## Commands and Flags

### Help and Discovery

```bash
kit -h, --help           # Show all functions (grouped by category)
kit <function> -h        # Show help for specific function
kit --search <keyword>   # Search functions by name
kit --list-categories    # List all categories with counts
```

### Examples

```bash
# Show all functions
$ kit -h

# Search for image functions
$ kit --search resize
  img-resize  (Image Processing)
  img-resize-width  (Image Processing)
  img-resize-percentage  (Image Processing)

# Show help for resize function
$ kit img-resize -h
Usage: kit img-resize <width>x<height> <file|directory> [options]
Example: 
  kit img-resize 800x600 photo.jpg
  kit img-resize 1024 . --recursive
  kit img-resize 1920x1080 . --dry-run

# Use a function
$ kit img-resize 800x600 photo.jpg
Created: photo-resized.jpg

# Rename image files (sanitize spaces and special characters)
$ kit img-rename "my photo 1.jpg"
Renamed: my photo 1.jpg -> my_photo_1.jpg
$ kit img-rename "VR (Quest/similar).jpg"
Renamed: VR (Quest/similar).jpg -> VR_Quest_similar.jpg
$ kit img-rename . --sep "-"
Renamed: image 1.png -> image-1.png

# Rename image files sequentially (image_1.jpg, image_2.png, ...)
$ kit img-rename . --name "photo"
Renamed: IMG_001.jpg -> photo_1.jpg
Renamed: DSC_123.png -> photo_2.png
$ kit img-rename . --name "img" --start 10
Renamed: photo.jpg -> img_10.jpg

# Recursive sanitization with dry-run
$ kit img-rename . --recursive --sep "-" --dry-run
Would rename: subfolder/my image.png -> subfolder/my-image.png
# Compress video (more complex with options)
$ kit compress-video video.mp4
$ kit compress-video video.mp4 -c 28 -o small.mp4
$ kit compress-video video.mp4 --width 1920 --preset medium
```

#### Audio Conversion and Download Examples

`convert-to-mp3` uses the `standard` VBR profile by default instead of forcing 320kbps. Use `speech` for voice recordings or set an exact bitrate when output size needs to be predictable.

```bash
# Balanced VBR; preserves the source channel count and sample rate
kit convert-to-mp3 recording.m4a

# Small voice recording: 48kbps mono at 24kHz
kit convert-to-mp3 recording.m4a --preset speech

# Exact bitrate and custom output
kit convert-to-mp3 music.m4a --bitrate 128 --output music.mp3

# yt-dlp audio-quality 5 is the balanced MP3 default; explicit bitrates also work
kit yt-download mp3 "https://youtube.com/watch?v=..."
kit yt-download mp3 "https://youtube.com/watch?v=..." 128K

# MP4 mode explicitly requests an MP4 merge/remux result
kit yt-download mp4 "https://youtube.com/watch?v=..."
```

| MP3 preset | Encoding | Suggested use |
|------------|----------|---------------|
| `speech` | 48kbps mono, 24kHz | Meetings, interviews, voice notes |
| `compact` | VBR quality 7 | Small files where some quality loss is acceptable |
| `standard` | VBR quality 5 | Default general-purpose conversion |
| `high` | VBR quality 2 | Music and quality-sensitive material |
| `maximum` | Constant 320kbps | Explicit maximum bitrate only |

`remove-audio` performs a video stream copy, so it is fast and does not reduce video quality. Use `--reencode` only when H.264 conversion is required. All local FFmpeg commands write to a temporary sibling file first; `--force` replaces an existing output only after conversion succeeds.

```bash
kit remove-audio video.mp4
kit remove-audio source.mkv --output silent.mkv
kit remove-audio source.mov --reencode --output silent.mp4
```

#### Video Compression Examples

The `compress-video` function supports multiple options for controlling output quality and file size:

```bash
# Basic compression (default settings)
kit compress-video video.mp4

# High compression for uploads (higher CRF = smaller file, lower quality)
kit compress-video video.mp4 -c 28 -o small.mp4

# Best quality preservation (lower CRF = better quality, larger file)
kit compress-video video.mp4 -c 18 -o high-quality.mp4

# Maximum dimensions; smaller sources are never upscaled
kit compress-video video.mp4 --width 1920
kit compress-video video.mp4 --width 1280 --preset medium

# Fast compression (trade quality for speed)
kit compress-video video.mp4 -p ultrafast -c 26

# Very slow compression (better quality at same bitrate)
kit compress-video video.mp4 -p veryslow -c 22
```

**Options:**
- `-o, --output FILE` — Output filename (default: input_compressed.mp4)
- `-c, --crf NUM` — Quality level 18-28 (default: 23, lower = better)
- `-p, --preset PRESET` — Encoding speed (default: slow)
  - Options: ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
- `-w, --width NUM` — Maximum width in pixels (default: 1280, minimum: 2; odd limits round down; `-1` disables scaling)
- `-b, --bitrate NUM` — Audio bitrate in k (default: 128)
- `-f, --force` — Replace an existing output only after encoding succeeds
- `-v, --verbose` — Show ffmpeg output

**CRF Quality Reference:**

| CRF Value | Quality | File Size | Use Case |
|-----------|---------|-----------|----------|
| 0-17 | Excellent (near lossless) | Very large | Archival, editing |
| 18-23 | High | Large | Default sweet spot |
| 24-28 | Medium | Medium | Web uploads, sharing |
| 29+ | Low | Small | Quick sharing, storage |

**Note:** Lower CRF = better quality but larger file. CRF does not guarantee a smaller result, so Kit reports the before/after sizes and warns when the output is larger.

#### PDF Processing Examples

```bash
# Split PDF into multiple files
# Default: creates "input_burst/" folder with "page_1.pdf", "page_2.pdf"...
kit pdf-burst document.pdf
kit pdf-burst document.pdf 2 -d my_folder    # 2 pages per file in custom folder
kit pdf-burst document.pdf -o "report_%d.pdf" # Custom filename pattern

# Split pages from a PDF
kit pdf-split document.pdf "1-10"
kit pdf-split document.pdf "1,3,5,7" -o odd_pages.pdf
kit pdf-split book.pdf "50-100" --force

# Merge multiple PDFs
kit pdf-merge part1.pdf part2.pdf part3.pdf
kit pdf-merge *.pdf -o combined.pdf

# Compress a PDF
kit pdf-compress large_scan.pdf
kit pdf-compress report.pdf -o report_small.pdf

# Rotate PDF pages
kit pdf-rotate scan.pdf 90                    # Rotate all pages
kit pdf-rotate doc.pdf 180 "1,3"              # Rotate specific pages
kit pdf-rotate book.pdf 270 "5-10" -o fixed.pdf
```

## Development & Extension

### Testing

Kit includes a comprehensive test suite that verifies all functionality:

```bash
# Run all tests
cd tests
./run-tests.sh

# Run with verbose output
./run-tests.sh -v

# Show help
./run-tests.sh -h
```

**Test Coverage:**
- Hermetic and integration coverage across all categories
- Image processing (resize, optimize, convert, thumbnail, rename)
- Media processing (compress, remove-audio, convert-to-mp3, yt-download)
- PDF processing (split, merge, compress, rotate)
- System utilities (mklink, killports, update, uninstall)
- Core functionality (dispatcher, help, search, categories)
- File listing (list-files, list-all, list-reverse, list-tree)

The test suite:
1. Checks dependencies with `kit deps-check`
2. Auto-generates test assets (images, videos, PDFs)
3. Tests all functions using `kit <command>` format
4. Downloads a real YouTube video for media processing tests
5. Shows detailed results and offers cleanup

See [tests/README.md](tests/README.md) for complete test documentation.

### Adding a New Function

1. **Generate template:**
   ```bash
   ./scripts/new-function.sh category function-name "Brief description"
   ```

2. **Implement the function** in `functions/category.sh`

3. **Validate:**
   ```bash
   ./scripts/validate-pattern.sh functions/category.sh
   ```

4. **Test:**
   ```bash
   source loader.zsh
   kit my-function -h
   kit my-function <test-args>
   ```

See [CONTRIBUTING.md](CONTRIBUTING.md) for complete guide.

### Creating a New Category

1. Create `functions/newcategory.sh` with proper headers
2. Add entry to `categories.conf`
3. Generate functions using the template generator

Example:
```bash
# Create new category for git tools
touch functions/git.sh

# Add to categories.conf
# git:Git Tools:Git-related utilities

# Generate first function
./scripts/new-function.sh git git-clean-branches "Remove merged branches"
```

### Validating Functions

Check if functions follow the pattern:
```bash
./scripts/validate-pattern.sh functions/myfile.sh
./scripts/validate-pattern.sh functions/*.sh  # Check all
```

### Configuring Navigation Shortcuts

The install script creates `shortcuts.conf` for you. This file is **user-specific** and **git-ignored**, so you can customize it without affecting the repository.

Add directory shortcuts to `shortcuts.conf`:
```bash
# Format: name|path|description
myproject|~/projects/myproject|My awesome project
docs|~/Documents|Documents folder
dev|~/Development|Main development directory
```

**Note:** The `shortcuts.conf` file is automatically created during installation. If you need to recreate it, copy from `shortcuts.conf.example`:
```bash
cp shortcuts.conf.example shortcuts.conf
```

Validate shortcuts for errors:
```bash
zsh ./scripts/validate-shortcuts.sh
```

Validate editor shortcuts for errors:
```bash
zsh ./scripts/validate-editors.sh
```

Disable auto-generation of shortcuts:
```bash
export KIT_AUTO_SHORTCUTS=false
```

### Tab Completion System

**The completion system is FULLY DYNAMIC!**

After adding new functions, editor shortcuts, or navigation shortcuts, simply reload your shell:

```bash
source ~/.zshrc
# or
exec zsh
```

The completion system automatically discovers:
- All functions from `functions/*.sh` (via `# Functions:` headers)
- All editor shortcuts from `editor.conf`
- All navigation shortcuts from `shortcuts.conf`

**No manual regeneration needed!**

To verify the completion system is working:
```bash
./scripts/generate-completions.sh
```

**For functions with custom completion options:**

If your function needs special tab completion (like `yt-download` completing `mp3|mp4`), edit the `_kit_get_custom_completion()` function in `completions/_kit`.

## Pattern Requirements

Every function must follow the pattern from `llm_prompts/kit_pattern.md`:

✓ **Help block** — Show usage with `-h` flag
✓ **Input validation** — Check required arguments (exit code 2)
✓ **File checking** — Verify files exist (exit code 1)
✓ **Dependency checking** — Verify required tools installed
✓ **Error handling** — Send errors to stderr with proper exit codes
✓ **Success message** — Confirm what was created/modified

Example:
```bash
my-function() {
    if [[ "$1" == "-h" || -z "$1" ]]; then
        cat << EOF
Usage: kit my-function <input>
Description: Does something useful
Example: kit my-function file.txt
EOF
        return 0
    fi

    [[ -f "$1" ]] || { echo "Error: File not found" >&2; return 1; }

    # Implementation
    echo "✅ Success message"
}
```

## Exit Codes

- **0** — Success
- **1** — Error (file not found, operation failed)
- **2** — Invalid usage (missing arguments, wrong format)

## Troubleshooting

### "Command not found" errors for basic commands (grep, wc, ls, etc.)

This was a bug in versions prior to v2.0.1 where the `path` variable conflicted with zsh's special `path` array, corrupting your PATH. **This has been fixed.**

If you're experiencing this:
```bash
# Update to the latest version
cd $KIT_EXT_DIR  # wherever you installed it
git pull  # or re-download

# Reload your shell
exec zsh
```

### Kit command not found
```bash
# Ensure loader is sourced
source ~/.zshrc

# Or manually load (if KIT_EXT_DIR is set)
source $KIT_EXT_DIR/loader.zsh
```

### Tab completion not working
```bash
# Rebuild completion cache
rm ~/.zcompdump*
exec zsh  # Restart shell
```

### Function not showing in help
```bash
# Check category header has function listed
grep "^# Functions:" $KIT_EXT_DIR/functions/category.sh

# Reload functions
source $KIT_EXT_DIR/loader.zsh
```

### Pre-existing aliases conflict
If you see "defining function based on alias" errors, remove the old alias definitions from your `.zshrc` and use the function versions instead via the loader.

## Updating Kit

If you installed Kit via git clone, you can update to the latest version using the built-in update command:

```bash
# Check for and install updates
kit update

# Check for updates without installing
kit update --check-only
```

The update command will:
- Fetch the latest changes from the git repository
- Compare your current version with the remote version
- Ask for confirmation before updating
- Reload the shell after update if needed

**Requirements:**
- Kit must be installed via git (not zip download)
- Git must be installed on your system
- Internet connection to fetch updates

If you installed Kit via zip download or don't have git, you can update manually by re-downloading from:
https://github.com/kristjanpikhof/kit-toolbox

## Uninstallation

To uninstall Kit, use the built-in uninstall command:

```bash
# Remove configuration only (keeps the kit-toolkit directory)
kit uninstall

# Remove configuration AND delete the kit-toolkit directory
kit uninstall --purge
```

The uninstall command will:
- Automatically detect your zsh config file (respects `ZDOTDIR`)
- Create a timestamped backup before making changes
- Remove the Kit configuration block from your config
- Optionally delete the kit-toolkit directory with `--purge`

To apply changes after uninstalling:
```bash
# Open a new terminal window, or
source ~/.zshrc
```

**Manual Uninstallation:**

If you prefer to uninstall manually:

```bash
# 1. Remove Kit configuration from ~/.zshrc
# Remove these lines (version number may vary):
#   # Kit X.Y.Z - Shell Toolkit
#   export KIT_EXT_DIR="..."
#   source "$KIT_EXT_DIR/loader.zsh"

# 2. Reload your shell
source ~/.zshrc

# 3. Optionally, delete the kit-toolkit directory
rm -rf $KIT_EXT_DIR  # wherever you installed it
```

## Migration from Legacy Functions

If you have existing shell functions and aliases:

1. Create appropriate category file in `functions/`
2. Migrate each function following the pattern
3. Update your `.zshrc` to source the loader instead of old files
4. Test each function works: `kit function-name -h`

For directory navigation shortcuts, add them to `shortcuts.conf`:
```bash
# Before: .zshrc had
alias myalias="cd /some/path"

# After: shortcuts.conf has
myalias|/some/path|My project directory

# Then just use: kit myalias
```

## Dependencies

### Managing Dependencies

Kit provides built-in commands to manage dependencies across platforms:

```bash
# Check what's installed and what's missing
kit deps-check

# Install all missing dependencies (auto-detects your package manager)
kit deps-install

# Preview what would be installed (dry run)
kit deps-install --dry-run

# Auto-confirm all prompts (for scripts)
kit deps-install --yes
```

`kit deps-check` distinguishes missing dependencies from unsupported installs.
For ImageMagick, Kit prefers v7+ with the `magick` command and will flag legacy
or misconfigured installs separately so upgrade steps are clearer.

### Supported Platforms

The toolkit supports **macOS** and **Linux** with the following package managers:

| OS | Package Managers |
|----|-----------------|
| macOS | Homebrew (`brew`) |
| Linux | apt (Debian/Ubuntu), dnf (Fedora), yum (RHEL/CentOS), pacman (Arch), zypper (openSUSE) |

### Required Dependencies by Category

| Category | Dependencies |
|----------|---|
| images | **ImageMagick v7+** (with `magick` command) |
| media | `yt-dlp`, `ffmpeg` |
| pdf | `qpdf` |
| system | `lsof` (for killports) |
| aliases | none |
| lsd | `lsd` |
| deps | none |

### Installing ImageMagick v7

**macOS:**
```bash
brew install imagemagick
```

**Linux:**
```bash
# Fedora (has v7 by default)
sudo dnf install imagemagick

# Arch Linux (has v7 by default)
sudo pacman -S imagemagick

# Debian/Ubuntu
# Ubuntu's default repo has v6, so you may need:
sudo add-apt-repository ppa:imagemagick/ppa
sudo apt update
sudo apt install imagemagick

# Or compile from source: https://imagemagick.org/script/download.php
```

**Verify v7 installation:**
```bash
# Should show 'magick' command available
magick --version
```

### Installing qpdf

**macOS:**
```bash
brew install qpdf
```

**Linux:**
```bash
# Debian/Ubuntu
sudo apt install qpdf

# Fedora
sudo dnf install qpdf

# Arch Linux
sudo pacman -S qpdf

# openSUSE
sudo zypper install qpdf
```

**Verify installation:**
```bash
qpdf --version
```

### Installing Other Dependencies

**The easiest way:**

```bash
# After installing Kit, use the built-in dependency installer
kit deps-install
```

**Or install manually:**

**macOS:**
```bash
brew install yt-dlp ffmpeg lsd
```

**Linux:**
```bash
# Debian/Ubuntu
sudo apt install yt-dlp ffmpeg lsd

# Fedora
sudo dnf install yt-dlp ffmpeg lsd

# Arch Linux
sudo pacman -S yt-dlp ffmpeg lsd
```

## Environment Variables

- **KIT_EXT_DIR** — Path to kit-toolkit directory (auto-detected during installation, no default)
- **KIT_AUTO_SHORTCUTS** — Enable/disable auto-generation of navigation shortcuts (default: `true`)
- **KIT_AUTO_EDITORS** — Enable/disable auto-generation of editor shortcuts (default: `true`)

When `KIT_AUTO_SHORTCUTS=false` or `KIT_AUTO_EDITORS=false` is set before loading Kit in a fresh shell, those config-backed commands are not generated and do not appear in `kit -h`.

**Note:** `KIT_EXT_DIR` is automatically set by the installer. The toolkit auto-detects its location, so it works from any directory.

Example:
```bash
export KIT_EXT_DIR="/your/custom/location/kit-toolkit"
export KIT_AUTO_SHORTCUTS=false
export KIT_AUTO_EDITORS=false
```

## Performance

Functions are **pre-loaded** at shell startup for instant access. Loading takes ~50ms for all functions.

Generated shortcut and editor functions are thin wrappers around internal handlers. Their target paths and editor commands are stored when Kit is sourced, so calls do not re-parse config files every time.

## Documentation

- **[CONTRIBUTING.md](CONTRIBUTING.md)** — Guide for adding new functions (for AI agents and humans)
- **[llm_prompts/kit_pattern.md](llm_prompts/kit_pattern.md)** — Complete pattern specification
- **[categories.conf](categories.conf)** — Category registry and descriptions
- **[tests/README.md](tests/README.md)** — Test suite documentation

## License

Use freely. Modify as needed.

## Version

**v2.9.0** — Safer shortcut/editor dispatch and loader characterization tests
**v2.8.1** — Installer now uses shared dependency checks
**v2.8.0** — Removed unusable `ccflare` command
**v2.7.1** — Version-aware ImageMagick dependency checks
**v2.7.0** — PDF bursting and enhanced splitting
**v2.6.0** — PDF processing functions
**v2.4.4** — Comprehensive test suite
**v2.4.3** — Enhanced image utilities and batch processing
**v2.4.1** — Dynamic tab completion system
**v2.4.0** — Configurable editor shortcuts

### Changelog
- **v2.9.0** (2026-07-03)
  - Reworked generated navigation shortcuts to use a source-time registry and internal handler instead of embedding target paths in generated function bodies.
  - Reworked generated editor shortcuts to use a source-time registry and internal handler instead of embedding editor commands in generated function bodies.
  - Editor commands are parsed as argv safely, so quoted arguments such as `'--one argument'` now pass as one argument.
  - Removed shortcuts/editors are unregistered on re-source; `KIT_AUTO_SHORTCUTS=false` and `KIT_AUTO_EDITORS=false` now disable kit-created functions when re-sourced.
  - Config parsing preserves `|` characters in descriptions via `lib/kit-core.zsh`.
  - Added `scripts/validate-editors.sh` and wired hermetic loader tests into `tests/run-tests.sh`.
  - Fixed validation scripts that used `local` at top level.
  - Added hermetic characterization tests for loader config, helper parsing, and discovery/completion behavior.
- **v2.8.1** (2026-03-17)
  - 🔧 `install.sh` now uses the shared dependency catalog and version-aware ImageMagick checks from `deps.sh`
  - 🧭 Added explicit invalid-usage handling to `goto` without changing its no-arg help behavior
- **v2.8.0** (2026-03-17)
  - 🗑️ Removed the unusable `ccflare` command and its config template
  - 🧪 Removed obsolete `ccflare` tests
- **v2.7.1** (2026-03-17)
  - 🔍 Centralized ImageMagick dependency validation in `deps.sh`
  - 🖼️ `deps-check` now distinguishes unsupported ImageMagick installs from missing dependencies
  - 🔧 Image functions use the shared dependency path for ImageMagick checks
  - 📝 Updated dependency documentation for version-aware ImageMagick handling
- **v2.7.0** (2026-02-09)
  - 📄 Added `pdf-burst` — Split PDF into multiple files of fixed page count
  - 📂 Default behavior creates dedicated subdirectory for burst files
  - ⚙️ Added `--dir` / `-d` option to specify custom output directory
  - 🧪 Added tests for pdf-burst functionality
- **v2.6.0** (2025-01-30)
  - 📄 Added PDF processing category with 4 functions
  - 📄 `pdf-split` — Extract page ranges with flexible syntax
  - 📄 `pdf-merge` — Combine multiple PDFs
  - 📄 `pdf-compress` — Reduce file size with linearization
  - 📄 `pdf-rotate` — Rotate pages by 90°, 180°, or 270°
  - 📦 Added qpdf dependency for PDF processing
  - 🧪 Added tests for all PDF functions
- **v2.4.4** (2026-01-03)
  - 🧪 Added comprehensive test suite with 39 tests
  - ✅ Tests all categories: images, media, system, core, file listing
  - 📦 Auto-generates test assets (images, videos) for testing
  - 🌐 Downloads real YouTube video for media processing validation
  - 📖 Added tests/README.md with test suite documentation
- **v2.4.3** (2026-01-02)
  - 📷 Enhanced `img-rename` with sanitization and sequential modes
  - 🖼️ Added directory target and recursive support (`-r`) to all major image utilities
  - 🔍 Added dry-run mode (`-n`) to image processing functions
  - 🔧 Improved Zsh compatibility and filename sanitization robustness
  - 🐛 Fixed `bad substitution` errors in Zsh and empty filename bugs
  - 🔒 Security hardening: input validation, path traversal prevention, command injection protection
  - 📝 Code review completed (see `.context/code-review-2025-01-03.md`)
- **v2.4.1** (2026-01-02)
  - ⚡ Fully dynamic auto-discovering tab completion system
  - 🔧 No manual regeneration needed - completions discover functions, editors, and shortcuts automatically
  - 📝 Updated documentation for dynamic completion behavior
- **v2.4.0** (2026-01-02)
  - ✏️ Added configurable editor shortcuts via `editor.conf`
  - ✏️ Auto-generates editor functions (code, zed, cursor, nvim, etc.)
  - ✏️ Replaces hardcoded `zed` function with flexible config system
  - 📝 Updated README with editor shortcuts documentation
  - 🔧 Added `KIT_AUTO_EDITORS` environment variable
  - 📁 Added `editor.conf.example` with common editor configurations
  - 🔧 Updated `editor.conf` to `.gitignore`
- **v2.3.0** (2026-01-02)
  - 🗑️ Added `uninstall` command - safely remove Kit configuration from your shell
  - 🗑️ Added `--purge` option to also delete the kit-toolkit directory
  - 🔒 Automatic backup creation before uninstalling
  - 📁 Supports `ZDOTDIR` for custom zsh config locations
  - 🆕 Added `update` command - update Kit via git to the latest version
  - 📦 Added `VERSION` file as single source of truth for version
  - 🔧 Version now injected into zshrc as `# Kit X.Y.Z - Shell Toolkit`
  - 🔧 Install/uninstall now version-agnostic, supports any future version
  - 📝 Updated README with clear "Zsh Only" requirement documentation
  - 📝 Updated README with uninstall and update command documentation
  - 🔧 Improved tab completion for `uninstall --purge` and `update --check-only`
- **v2.2.0** (2026-01-02)
  - 📦 Added `deps-install` command - cross-platform dependency installer
  - 📦 Added `deps-check` command - check status of all dependencies
  - 🌍 Auto-detects OS and package manager (brew, apt, dnf, yum, pacman, zypper)
  - 📝 Updated README with dependency management section
  - 🔧 Updated installer with cross-platform package manager detection
- **v2.1.0** (2026-01-02)
  - 🌍 Added Linux/macOS cross-platform support
  - 🖼️ Image functions now require ImageMagick v7+ (`magick` command)
  - 🔧 Fixed `realpath` compatibility for macOS (uses Perl/zsh fallback)
  - 📝 Updated tab completion with correct function names
  - 📚 Updated documentation with Linux installation instructions
  - 🔪 Added `killports()` function to kill processes by network port
- **v2.0.1** (2025-12-29)
  - 🐛 Fixed PATH corruption bug caused by `path` variable name conflict
  - ✨ Added automated installation script (`install.sh`)
  - 📝 Improved installation documentation
- **v2.0.0**
  - Initial modular release

---

For questions or to add functions, see [CONTRIBUTING.md](CONTRIBUTING.md)
