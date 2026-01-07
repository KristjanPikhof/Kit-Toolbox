#!/usr/bin/env bash
# run-tests.sh - Comprehensive test suite for Kit's Toolkit
# Compatible with both bash and zsh

# Detect shell and set compatibility
if [ -n "$ZSH_VERSION" ]; then
    # Zsh: ${0:A:h} gives absolute path of script's directory
    SCRIPT_DIR="${0:A:h}"
    KIT_ROOT="${SCRIPT_DIR:h}"
elif [ -n "$BASH_VERSION" ]; then
    # Bash: use BASH_SOURCE to get script path
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
else
    # Fallback: assume script is run from its location
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    KIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
fi

ASSETS_DIR="$SCRIPT_DIR/assets"

# Test video URL (short test video)
TEST_VIDEO_URL="https://youtu.be/1SBxsv_T_Jw"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Options
VERBOSE=${VERBOSE:-0}
SKIP_ASSET_SETUP=false

# Enable nullglob for bash (zsh uses setopt)
if [ -z "$ZSH_VERSION" ]; then
    shopt -s nullglob 2>/dev/null
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -v, --verbose     Show detailed output for each test"
            echo "  -h, --help        Show this help"
            echo ""
            echo "This script will:"
            echo "  1. Check dependencies with 'kit deps-check'"
            echo "  2. Clean and recreate test assets"
            echo "  3. Run all tests"
            echo "  4. Offer to clean up assets after completion"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 -h' for help"
            exit 1
            ;;
    esac
done

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         Kit's Toolkit - Comprehensive Test Suite        ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${CYAN}──────────────────────────────────────────────────────────────${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}──────────────────────────────────────────────────────────────${NC}"
    echo ""
}

# Test function
run_test() {
    local name="$1"
    local test_func="$2"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [[ $VERBOSE -eq 1 ]]; then
        echo -e "${BLUE}Testing:${NC} $name"
    fi

    # Run the test function
    if eval "$test_func" >/dev/null 2>&1; then
        echo -e "${GREEN}[PASS]${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}[FAIL]${NC} $name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        if [[ $VERBOSE -eq 1 ]]; then
            echo -e "${GRAY}Re-running with output:${NC}"
            eval "$test_func" || true
        fi
        return 1
    fi
}

# Check if a file exists using glob pattern (cross-shell compatible)
# Uses ls which works in both bash and zsh
has_test_file() {
    local pattern="$1"
    local dir_name="$(dirname "$pattern")"
    local base_name="$(basename "$pattern")"

    # ls will return 0 if files match, non-zero otherwise
    ls "$dir_name"/"$base_name" >/dev/null 2>&1
}

# Helper to find files matching a pattern (cross-shell compatible)
find_matching_files() {
    local pattern="$1"

    # ls -1 will list matching files, one per line
    # Disable glob expansion briefly to safely pass the pattern
    set -f  # Disable glob expansion
    ls -1 -- $pattern 2>/dev/null
    set +f  # Re-enable glob expansion
}

# Count matching files (cross-shell compatible)
count_matching_files() {
    local pattern="$1"

    # Count matching files using ls
    local count
    count=$(ls -1 $pattern 2>/dev/null | wc -l)
    echo "$count"
}

# ============================================================================
# LOAD KIT FUNCTIONS
# ============================================================================

print_header

if [[ -f "$KIT_ROOT/loader.zsh" ]]; then
    export KIT_EXT_DIR="$KIT_ROOT"
    source "$KIT_ROOT/loader.zsh" 2>/dev/null || {
        echo -e "${RED}Error: Failed to load Kit's Toolkit${NC}"
        exit 1
    }
else
    echo -e "${RED}Error: Cannot find loader.zsh at $KIT_ROOT${NC}"
    exit 1
fi

# ============================================================================
# STEP 1: DEPENDENCY CHECK
# ============================================================================

print_section "Step 1: Dependency Check"

echo "Checking Kit toolkit dependencies..."
echo ""

if ! kit deps-check; then
    echo ""
    echo -e "${YELLOW}⚠️  Some dependencies are missing. Install with:${NC}"
    echo "  kit deps-install"
    echo ""
    echo -e "${BOLD}Continue anyway? (y/N):${NC} "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Exiting. Please install missing dependencies first."
        exit 1
    fi
fi

# ============================================================================
# STEP 2: ASSET SETUP
# ============================================================================

print_section "Step 2: Test Asset Setup"

# Clean existing assets
if [[ -d "$ASSETS_DIR" ]]; then
    echo "Cleaning existing test assets..."
    rm -rf "$ASSETS_DIR"
    # Wait a moment for filesystem to sync
    sleep 0.1
fi

# Create asset directories
mkdir -p "$ASSETS_DIR/images"
mkdir -p "$ASSETS_DIR/video"
mkdir -p "$ASSETS_DIR/audio"

echo "Created test asset directories:"
echo "  $ASSETS_DIR/images/"
echo "  $ASSETS_DIR/video/"
echo "  $ASSETS_DIR/audio/"
echo ""

# Generate test images
echo "Generating test images..."

if command -v magick &>/dev/null; then
    # Standard test images
    magick -size 1920x1080 xc:blue "$ASSETS_DIR/images/test_input_1920x1080.jpg" 2>/dev/null
    magick -size 800x600 xc:red "$ASSETS_DIR/images/test_input_800x600.jpg" 2>/dev/null
    magick -size 2500x1500 xc:green "$ASSETS_DIR/images/test_input_large.jpg" 2>/dev/null
    magick -size 300x300 xc:yellow "$ASSETS_DIR/images/test_input_small.jpg" 2>/dev/null
    magick -size 1024x768 xc:purple "$ASSETS_DIR/images/test_input.webp" 2>/dev/null

    # Filenames with spaces and special chars (for img-rename testing)
    magick -size 800x600 xc:orange "$ASSETS_DIR/images/test photo with spaces.jpg" 2>/dev/null
    magick -size 800x600 xc:pink "$ASSETS_DIR/images/test-photo(VR~quest).jpg" 2>/dev/null

    echo -e "${GREEN}✓${NC} Created test images"

elif command -v convert &>/dev/null; then
    convert -size 1920x1080 xc:blue "$ASSETS_DIR/images/test_input_1920x1080.jpg" 2>/dev/null
    convert -size 800x600 xc:red "$ASSETS_DIR/images/test_input_800x600.jpg" 2>/dev/null
    convert -size 2500x1500 xc:green "$ASSETS_DIR/images/test_input_large.jpg" 2>/dev/null
    convert -size 300x300 xc:yellow "$ASSETS_DIR/images/test_input_small.jpg" 2>/dev/null
    echo -e "${GREEN}✓${NC} Created test images"
else
    echo -e "${YELLOW}⚠️  ImageMagick not found. Image tests will be limited.${NC}"
fi

# Generate test video
echo "Generating test video..."

if command -v ffmpeg &>/dev/null; then
    # Use filter_complex to generate test video with audio
    ffmpeg -loglevel error \
        -filter_complex "testsrc=duration=5:size=640x360:rate=30[v];sine=frequency=1000:duration=5[a]" \
        -map "[v]" -map "[a]" \
        -c:v libx264 -preset ultrafast -crf 23 -pix_fmt yuv420p \
        -c:a aac -b:a 128k \
        "$ASSETS_DIR/video/test_input_video.mp4" -y 2>/dev/null

    if [[ -f "$ASSETS_DIR/video/test_input_video.mp4" ]]; then
        echo -e "${GREEN}✓${NC} Created test video"
    else
        echo -e "${YELLOW}⚠️  Failed to create test video${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  ffmpeg not found. Video tests will be limited.${NC}"
fi

echo ""
echo "Test assets ready in: $ASSETS_DIR"

# ============================================================================
# STEP 3: RUN TESTS
# ============================================================================

print_section "Step 3: Running Tests"

# ============================================================================
# IMAGE PROCESSING TESTS
# ============================================================================

print_section "Image Processing Tests"

# Help tests
run_test "img-rename: help works" "kit img-rename -h"
run_test "img-resize-width: help works" "kit img-resize-width -h"
run_test "img-resize-percentage: help works" "kit img-resize-percentage -h"
run_test "img-optimize: help works" "kit img-optimize -h"
run_test "img-convert: help works" "kit img-convert -h"
run_test "img-thumbnail: help works" "kit img-thumbnail -h"
run_test "img-resize: help works" "kit img-resize -h"
run_test "img-resize-exact: help works" "kit img-resize-exact -h"
run_test "img-resize-fill: help works" "kit img-resize-fill -h"
run_test "img-adaptive-resize: help works" "kit img-adaptive-resize -h"
run_test "img-batch-resize: help works" "kit img-batch-resize -h"
run_test "img-resize-shrink-only: help works" "kit img-resize-shrink-only -h"
run_test "img-resize-colorspace: help works" "kit img-resize-colorspace -h"

# Functional tests with actual files
if has_test_file "$ASSETS_DIR/images/*.jpg"; then
    echo ""
    echo "Running functional image tests..."

    # Test img-resize-width (creates output file with -resized suffix)
    if [[ -f "$ASSETS_DIR/images/test_input_800x600.jpg" ]]; then
        cd "$ASSETS_DIR/images"
        # Clean up any existing output
        rm -f "test_input_800x600-resized.jpg" 2>/dev/null
        run_test "img-resize-width: functional test" \
            "kit img-resize-width 400 test_input_800x600.jpg && [[ -f 'test_input_800x600-resized.jpg' ]]"
        cd - >/dev/null
    fi

    # Test img-optimize (creates output file with -optimized suffix)
    if [[ -f "$ASSETS_DIR/images/test_input_1920x1080.jpg" ]]; then
        cd "$ASSETS_DIR/images"
        # Clean up any existing output
        rm -f "test_input_1920x1080-optimized.jpg" 2>/dev/null
        run_test "img-optimize: functional test" \
            "kit img-optimize test_input_1920x1080.jpg && [[ -f 'test_input_1920x1080-optimized.jpg' ]]"
        cd - >/dev/null
    fi

    # Test img-thumbnail (creates output file with -resized suffix, same as img-resize-width)
    if [[ -f "$ASSETS_DIR/images/test_input_small.jpg" ]]; then
        cd "$ASSETS_DIR/images"
        # Clean up any existing output - use different file to avoid conflict
        rm -f "test_input_small-resized.jpg" 2>/dev/null
        run_test "img-thumbnail: functional test" \
            "kit img-thumbnail 150 test_input_small.jpg && [[ -f 'test_input_small-resized.jpg' ]]"
        cd - >/dev/null
    fi

    # Test img-rename dry-run with spaces
    if [[ -f "$ASSETS_DIR/images/test photo with spaces.jpg" ]]; then
        cd "$ASSETS_DIR/images"
        run_test "img-rename: dry-run with spaces" \
            "kit img-rename 'test photo with spaces.jpg' --dry-run"
        cd - >/dev/null
    fi
fi

# ============================================================================
# MEDIA PROCESSING TESTS
# ============================================================================

print_section "Media Processing Tests"

# Help tests
run_test "yt-download: help works" "kit yt-download -h"
run_test "remove-audio: help works" "kit remove-audio -h"
run_test "convert-to-mp3: help works" "kit convert-to-mp3 -h"
run_test "compress-video: help works" "kit compress-video -h"

# Functional tests
if [[ -f "$ASSETS_DIR/video/test_input_video.mp4" ]]; then
    cd "$ASSETS_DIR/video"

    # Test compress-video (creates output file)
    compressed_output="test_input_video_compressed.mp4"
    rm -f "$compressed_output" 2>/dev/null
    run_test "compress-video: functional test" \
        "kit compress-video test_input_video.mp4 -o $compressed_output && [[ -f '$compressed_output' ]]"

    # Test remove-audio (creates output file with _noaudio suffix)
    no_audio_output="test_input_video_noaudio.mp4"
    rm -f "$no_audio_output" 2>/dev/null
    run_test "remove-audio: functional test" \
        "kit remove-audio test_input_video.mp4 && [[ -f '$no_audio_output' ]]"

    cd - >/dev/null
fi

# Test yt-download (network test - may be skipped if no network)
echo ""
echo -e "${GRAY}Note: yt-download test requires network access...${NC}"
if command -v yt-dlp &>/dev/null; then
    cd "$ASSETS_DIR/video"

    # Download a short test video (mark as total but don't fail test suite)
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo -e "${BLUE}Testing:${NC} yt-download: download test video"

    # Clean up any existing downloads from this video
    # Use find to handle multiple extensions cross-shell
    find . -maxdepth 1 -name "Minecraft in 15 seconds*" -type f \( -name "*.mkv" -o -name "*.mp4" -o -name "*.webp" \) -delete 2>/dev/null

    if kit yt-download mp4 "$TEST_VIDEO_URL" >/dev/null 2>&1; then
        # Check if any video file was created (mkv or mp4)
        # Use find for cross-shell compatibility
        youtube_video_file=""
        for ext in mkv mp4; do
            youtube_video_file=$(find . -maxdepth 1 -name "Minecraft in 15 seconds*.$ext" -type f -print -quit 2>/dev/null)
            if [[ -n "$youtube_video_file" ]]; then
                # Remove leading ./ for consistency
                youtube_video_file="${youtube_video_file#./}"
                break
            fi
        done

        if [[ -n "$youtube_video_file" && -f "$youtube_video_file" ]]; then
            echo -e "${GREEN}[PASS]${NC} yt-download: download test video"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            youtube_download_success=true
        else
            echo -e "${YELLOW}[SKIP]${NC} yt-download: download test video (download succeeded but no file found)"
            TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
            youtube_download_success=false
        fi
    else
        echo -e "${YELLOW}[SKIP]${NC} yt-download: download test video (network or video unavailable)"
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
        youtube_download_success=false
    fi

    if [[ "$youtube_download_success" == "true" && -n "$youtube_video_file" ]]; then
        # Get base filename for output checks
        youtube_base="${youtube_video_file%.*}"

        # Test compress on downloaded video
        youtube_compressed="youtube_compressed.mp4"
        rm -f "$youtube_compressed" 2>/dev/null
        run_test "compress-video: youtube video" \
            "kit compress-video '$youtube_video_file' -o $youtube_compressed && [[ -f '$youtube_compressed' ]]"

        # Test convert-to-mp3 on downloaded video (output: <base>.mp3)
        youtube_mp3="${youtube_base}.mp3"
        rm -f "$youtube_mp3" 2>/dev/null
        run_test "convert-to-mp3: youtube video to mp3" \
            "kit convert-to-mp3 '$youtube_video_file' && [[ -f '$youtube_mp3' ]]"

        # Test remove-audio on downloaded video (output: <base>_noaudio.mp4)
        youtube_noaudio="${youtube_base}_noaudio.mp4"
        rm -f "$youtube_noaudio" 2>/dev/null
        run_test "remove-audio: youtube video remove audio" \
            "kit remove-audio '$youtube_video_file' && [[ -f '$youtube_noaudio' ]]"
    fi

    cd - >/dev/null
else
    echo -e "${YELLOW}⊘ yt-download: yt-dlp not installed, skipping${NC}"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
fi

# ============================================================================
# SYSTEM UTILITIES TESTS
# ============================================================================

print_section "System Utilities Tests"

run_test "mklink: help works" "kit mklink -h"

# Test mklink functionality (use a function to properly scope local variables)
test_mklink_functionality() {
    local tmpdir=$(mktemp -d)
    local src="$tmpdir/source.txt"
    local dst="$tmpdir/link.txt"
    echo "test" > "$src"
    kit mklink "$src" "$dst" && [[ -L "$dst" ]]
    local result=$?
    rm -rf "$tmpdir"
    return $result
}
run_test "mklink: create symbolic link" "test_mklink_functionality"

run_test "killports: help works" "kit killports -h"
run_test "update: help works" "kit update -h"
run_test "uninstall: help works" "kit uninstall -h"

# ============================================================================
# CORE & NAVIGATION TESTS
# ============================================================================

print_section "Core & Navigation Tests"

run_test "kit dispatcher: main help works" "kit -h | grep -q Kit"
run_test "kit --list-categories: lists categories" "kit --list-categories | grep -q Image"
run_test "kit --search: search functions" "kit --search resize | grep -q img-resize"

# CCFlare tests
run_test "ccflare: help works" "kit ccflare -h"
run_test "ccflare: help shows toggle option" "kit ccflare -h | grep -q toggle"
run_test "ccflare: status command works" "kit ccflare status | grep -q 'CCFlare Status'"

# ============================================================================
# FILE LISTING TESTS
# ============================================================================

print_section "File Listing Tests"

run_test "list-files: help works" "kit list-files -h"
run_test "list-all: help works" "kit list-all -h"
run_test "list-reverse: help works" "kit list-reverse -h"
run_test "list-tree: help works" "kit list-tree -h"

# ============================================================================
# TEST SUMMARY
# ============================================================================

print_section "Test Summary"

echo ""
if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✅ All tests passed!${NC}"
else
    echo -e "${RED}${BOLD}❌ Some tests failed${NC}"
fi

echo ""
echo -e "Total:   ${BOLD}${TESTS_TOTAL}${NC}"
echo -e "${GREEN}Passed:  ${TESTS_PASSED}${NC}"
echo -e "${RED}Failed:  ${TESTS_FAILED}${NC}"
echo -e "${GRAY}Skipped: ${TESTS_SKIPPED}${NC}"
echo ""

# Show generated files
print_section "Generated Test Files"

echo "Image outputs:"

# Helper function to list files matching a pattern using find (cross-shell compatible)
list_output_files() {
    local pattern="$1"
    local dir_name="$(dirname "$pattern")"
    local base_name="$(basename "$pattern")"
    local found=false

    # Convert glob pattern to find-compatible pattern
    # *-resized.jpg becomes *-resized.jpg (find uses shell-like patterns)
    # First, check if any files match using ls -1 pattern 2>/dev/null (cross-shell)
    local files_output=""
    files_output=$(ls -1 "$dir_name"/"$base_name" 2>/dev/null) && found=true

    if [[ "$found" == "true" ]]; then
        echo "$files_output" | while IFS= read -r f; do
            echo "  $(basename "$f")"
        done
    else
        echo "  (none)"
    fi
}

list_output_files "$ASSETS_DIR/images/*-resized.jpg"
list_output_files "$ASSETS_DIR/images/*-optimized.jpg"
list_output_files "$ASSETS_DIR/images/*-thumb.jpg"

echo ""
echo "Video outputs:"
list_output_files "$ASSETS_DIR/video/*_compressed.mp4"
list_output_files "$ASSETS_DIR/video/*_noaudio.mp4"

# ============================================================================
# CLEANUP PROMPT
# ============================================================================

print_section "Cleanup"

echo -e "${BOLD}Test complete! Clean up test assets?${NC}"
echo ""
echo "This will delete: $ASSETS_DIR"
echo ""
echo -e "${YELLOW}Options:${NC}"
echo "  [Y]es - Delete all test assets"
echo "  [N]o  - Keep assets for inspection"
echo ""
echo -n "Your choice: "
read -r response

case "$response" in
    y|Y|yes|YES)
        echo ""
        echo "Deleting test assets..."
        rm -rf "$ASSETS_DIR"
        echo -e "${GREEN}✓ Cleanup complete${NC}"
        ;;
    *)
        echo ""
        echo "Assets kept in: $ASSETS_DIR"
        echo "Delete manually with: rm -rf $ASSETS_DIR"
        ;;
esac

echo ""

# Exit with appropriate code
if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
else
    exit 0
fi
