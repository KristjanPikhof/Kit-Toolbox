# Kit Builder - Examples

This document provides concrete examples of using the Kit Builder skill to create different types of functions.

## Example 1: Simple File Conversion Function

**User Request:** "I want to create a function that converts PNG files to JPEG format"

**Skill Questions:**
- Should it convert one file or batch process?
- What quality level for JPEG? (default 90)
- Should it preserve the original file?
- Where should output go?

**User Answers:**
- Single file at a time
- Quality 90 by default
- Yes, preserve original
- Same directory with .jpg extension

**Implementation:**

```bash
# Generated using:
./scripts/new-function.sh images convert-png-to-jpg "Convert PNG to JPEG format"

# In functions/images.sh:
convert-png-to-jpg() {
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit convert-png-to-jpg <input.png> [quality]
Description: Convert PNG image to JPEG format with specified quality
Examples:
  kit convert-png-to-jpg image.png           # Convert with quality 90
  kit convert-png-to-jpg image.png 85        # Convert with quality 85
EOF
        return 0
    fi

    # Input validation
    if [[ -z "$1" ]]; then
        echo "Error: Missing input file" >&2
        return 2
    fi

    if [[ ! -f "$1" ]]; then
        echo "Error: File '$1' does not exist" >&2
        return 1
    fi

    # Check file extension
    if [[ ! "$1" =~ \.png$ ]]; then
        echo "Error: Input must be a PNG file" >&2
        return 2
    fi

    # Check ImageMagick dependency
    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
        return 1
    fi

    # Process
    local input="$1"
    local quality="${2:-90}"
    local output="${input%.png}.jpg"

    if ! magick "$input" -quality "$quality" "$output"; then
        echo "Error: Conversion failed" >&2
        return 1
    fi

    echo "✅ Converted '$input' → '$output' (quality: $quality)"
    return 0
}
```

**Testing:**
```bash
source $KIT_EXT_DIR/loader.zsh
kit convert-png-to-jpg -h
kit convert-png-to-jpg test.png
kit convert-png-to-jpg test.png 95
```

---

## Example 2: Batch Processing Function

**User Request:** "Create a function to optimize all WebP images in a directory"

**Skill Questions:**
- What does "optimize" mean? (compress, resize, strip metadata?)
- Should it recurse into subdirectories?
- Should it modify files in place or create new ones?
- Any specific compression level?

**User Answers:**
- Compress and strip metadata
- No recursion, current directory only
- Modify in place
- Compression level 85

**Implementation:**

```bash
# Generated using:
./scripts/new-function.sh images optimize-webp-batch "Optimize all WebP images in directory"

# In functions/images.sh:
optimize-webp-batch() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit optimize-webp-batch [directory]
Description: Optimize all WebP images in directory by compressing and stripping metadata
Examples:
  kit optimize-webp-batch           # Optimize in current directory
  kit optimize-webp-batch ~/images  # Optimize in specific directory
EOF
        return 0
    fi

    # Check ImageMagick dependency
    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
        return 1
    fi

    # Default to current directory
    local dir="${1:-.}"

    # Validate directory
    if [[ ! -d "$dir" ]]; then
        echo "Error: Directory '$dir' does not exist" >&2
        return 1
    fi

    # Find all WebP files
    local count=0
    local processed=0

    for file in "$dir"/*.webp; do
        # Check if glob matched anything
        [[ -f "$file" ]] || continue
        ((count++))

        # Optimize the file
        if magick "$file" -strip -quality 85 "$file"; then
            ((processed++))
            echo "Optimized: $(basename "$file")"
        else
            echo "Failed: $(basename "$file")" >&2
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo "No WebP files found in '$dir'"
        return 0
    fi

    echo "✅ Optimized $processed/$count WebP images in '$dir'"
    return 0
}
```

---

## Example 3: System Utility with Options

**User Request:** "I need a function to create backups of important config files"

**Skill Questions:**
- Which config files? (let user specify patterns)
- Where should backups go?
- Should it include timestamp in backup name?
- Should it compress backups?

**User Answers:**
- User specifies file/pattern
- Backups go to ~/backups/
- Yes, include timestamp
- Optional compression with -z flag

**Implementation:**

```bash
# Generated using:
./scripts/new-function.sh system backup-config "Backup configuration files with timestamp"

# In functions/system.sh:
backup-config() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit backup-config [-z] <file_or_pattern>
Description: Create timestamped backup of config files
Options:
  -z    Compress backup with gzip
Examples:
  kit backup-config ~/.zshrc
  kit backup-config -z ~/.config/nvim/init.lua
  kit backup-config "~/.ssh/config*"
EOF
        return 0
    fi

    local compress=false
    local file=""

    # Parse options
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -z)
                compress=true
                shift
                ;;
            *)
                file="$1"
                shift
                ;;
        esac
    done

    # Validate input
    if [[ -z "$file" ]]; then
        echo "Error: Missing file or pattern" >&2
        return 2
    fi

    # Expand tilde
    file="${file/#\~/$HOME}"

    # Check if file exists
    if [[ ! -e "$file" ]]; then
        echo "Error: File '$file' does not exist" >&2
        return 1
    fi

    # Create backup directory
    local backup_dir="$HOME/backups"
    mkdir -p "$backup_dir" || {
        echo "Error: Could not create backup directory" >&2
        return 1
    }

    # Generate timestamp
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local basename=$(basename "$file")
    local backup_name="${basename}.${timestamp}.bak"

    # Create backup
    if $compress; then
        backup_name="${backup_name}.gz"
        if ! gzip -c "$file" > "$backup_dir/$backup_name"; then
            echo "Error: Backup failed" >&2
            return 1
        fi
    else
        if ! cp "$file" "$backup_dir/$backup_name"; then
            echo "Error: Backup failed" >&2
            return 1
        fi
    fi

    echo "✅ Backed up '$file' → '$backup_dir/$backup_name'"
    return 0
}
```

---

## Example 4: Creating a New Category

**User Request:** "I want to create functions for managing Docker containers"

**Skill Analysis:**
- Multiple related functions planned (3+)
- Shared dependency (docker)
- Distinct from existing categories
- Recommendation: Create new category

**Steps:**

1. **Create category file:**

```bash
cat > $KIT_EXT_DIR/functions/docker.sh << 'EOF'
# docker.sh - Docker container management utilities
# Category: Docker Tools
# Description: Docker container and image management utilities
# Dependencies: docker
# Functions: docker-clean, docker-list-sizes, docker-shell

docker-clean() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit docker-clean
Description: Remove all stopped containers and dangling images
EOF
        return 0
    fi

    if ! command -v docker &> /dev/null; then
        echo "Error: Docker not installed" >&2
        return 1
    fi

    echo "Removing stopped containers..."
    docker container prune -f

    echo "Removing dangling images..."
    docker image prune -f

    echo "✅ Docker cleanup complete"
}

docker-list-sizes() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit docker-list-sizes
Description: List all Docker images sorted by size
EOF
        return 0
    fi

    if ! command -v docker &> /dev/null; then
        echo "Error: Docker not installed" >&2
        return 1
    fi

    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | sort -k3 -h
}

docker-shell() {
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit docker-shell <container_name>
Description: Open a shell in a running Docker container
Examples:
  kit docker-shell my-container
EOF
        return 0
    fi

    if ! command -v docker &> /dev/null; then
        echo "Error: Docker not installed" >&2
        return 1
    fi

    if [[ -z "$1" ]]; then
        echo "Error: Missing container name" >&2
        return 2
    fi

    # Try bash first, fall back to sh
    if ! docker exec -it "$1" bash 2>/dev/null; then
        docker exec -it "$1" sh
    fi
}
EOF
```

2. **Add to categories.conf:**

```bash
echo "docker:Docker Tools:Docker container and image management utilities" >> $KIT_EXT_DIR/categories.conf
```

3. **Reload and test:**

```bash
source $KIT_EXT_DIR/loader.zsh
kit -h  # Should show Docker Tools category
kit docker-clean -h
```

---

## Example 5: Function with Complex Error Handling

**User Request:** "Create a function to download and convert YouTube videos to MP3"

**Already exists as `yt-download` but here's how it would be created:**

```bash
# In functions/media.sh:
yt-download() {
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit yt-download <url> [format]
Description: Download YouTube videos or extract audio to MP3
Arguments:
  url       YouTube video URL
  format    mp3 or mp4 (default: mp3)
Examples:
  kit yt-download https://youtube.com/watch?v=xyz
  kit yt-download https://youtube.com/watch?v=xyz mp4
EOF
        return 0
    fi

    # Check dependencies
    if ! command -v yt-dlp &> /dev/null; then
        echo "Error: yt-dlp not installed. Install with: brew install yt-dlp" >&2
        return 1
    fi

    if ! command -v ffmpeg &> /dev/null; then
        echo "Error: ffmpeg not installed. Install with: brew install ffmpeg" >&2
        return 1
    fi

    # Validate URL
    local url="$1"
    if [[ ! "$url" =~ ^https?://(www\.)?(youtube\.com|youtu\.be) ]]; then
        echo "Error: Invalid YouTube URL" >&2
        return 2
    fi

    # Validate format
    local format="${2:-mp3}"
    if [[ ! "$format" =~ ^(mp3|mp4)$ ]]; then
        echo "Error: Format must be 'mp3' or 'mp4'" >&2
        return 2
    fi

    # Download based on format
    if [[ "$format" == "mp3" ]]; then
        echo "Downloading audio as MP3..."
        if ! yt-dlp -x --audio-format mp3 --audio-quality 320K "$url"; then
            echo "Error: Download failed" >&2
            return 1
        fi
        echo "✅ Downloaded audio as MP3 (320kbps)"
    else
        echo "Downloading video as MP4..."
        if ! yt-dlp -f "bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best" --merge-output-format mp4 "$url"; then
            echo "Error: Download failed" >&2
            return 1
        fi
        echo "✅ Downloaded video as MP4"
    fi

    return 0
}
```

---

## Testing Patterns

### Test Script Template

Create a test script for your function:

```bash
#!/bin/bash
# test-my-function.sh

echo "=== Testing my-function ==="

# Setup
source "$KIT_EXT_DIR/loader.zsh"
test_file="/tmp/test-input.txt"
echo "test content" > "$test_file"

# Test 1: Help
echo -n "Test 1 (Help): "
if kit my-function -h &>/dev/null; then
    echo "✅ PASS"
else
    echo "❌ FAIL"
fi

# Test 2: No arguments
echo -n "Test 2 (No args): "
if ! kit my-function &>/dev/null; then
    exit_code=$?
    if [[ $exit_code -eq 2 ]]; then
        echo "✅ PASS (exit 2)"
    else
        echo "❌ FAIL (exit $exit_code, expected 2)"
    fi
else
    echo "❌ FAIL (should have failed)"
fi

# Test 3: File not found
echo -n "Test 3 (Missing file): "
if ! kit my-function /nonexistent 2>/dev/null; then
    exit_code=$?
    if [[ $exit_code -eq 1 ]]; then
        echo "✅ PASS (exit 1)"
    else
        echo "❌ FAIL (exit $exit_code, expected 1)"
    fi
else
    echo "❌ FAIL (should have failed)"
fi

# Test 4: Success
echo -n "Test 4 (Success): "
if kit my-function "$test_file" &>/dev/null; then
    echo "✅ PASS (exit 0)"
else
    echo "❌ FAIL (exit $?)"
fi

# Cleanup
rm -f "$test_file"

echo "=== Tests complete ==="
```

---

## Common Patterns Quick Reference

**Single file input:**
```bash
[[ -z "$1" ]] && { echo "Error: Missing input" >&2; return 2; }
[[ -f "$1" ]] || { echo "Error: File not found" >&2; return 1; }
```

**Directory input:**
```bash
local dir="${1:-.}"  # Default to current directory
[[ -d "$dir" ]] || { echo "Error: Not a directory" >&2; return 1; }
```

**Dependency check:**
```bash
command -v tool &>/dev/null || {
    echo "Error: tool not installed. Install with: brew install pkg" >&2
    return 1
}
```

**Flag parsing:**
```bash
while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--flag) flag=true; shift ;;
        -o|--option) option="$2"; shift 2 ;;
        *) input="$1"; shift ;;
    esac
done
```

**Progress indication:**
```bash
local current=1
for file in *.jpg; do
    printf "\rProcessing %d/%d: %s" "$current" "$total" "$(basename "$file")"
    # Process file
    ((current++))
done
printf "\n"
```

These examples demonstrate the full range of function creation scenarios and patterns supported by the Kit Builder skill.
