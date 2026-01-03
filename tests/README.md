# Kit's Toolkit - Test Suite

Comprehensive test suite that verifies all toolkit functionality with a single command.

**Shell Compatibility:** The test suite works with both **bash** and **zsh**.

## Quick Start

```bash
cd tests
./run-tests.sh          # Run all tests
./run-tests.sh -v       # Run with verbose output
./run-tests.sh -h       # Show help
```

## Test Overview

The test suite verifies **39 tests** across all toolkit categories:

| Category | Tests | Coverage |
|----------|-------|----------|
| Image Processing | 17 | Help + functional tests for resize, optimize, convert, thumbnail, rename |
| Media Processing | 9 | Help + functional tests for compress, remove-audio, convert-to-mp3, yt-download |
| System Utilities | 5 | Help + functional tests for mklink, killports, update, uninstall |
| Core & Navigation | 3 | Dispatcher, help, search, categories |
| File Listing | 4 | Help tests for list-files, list-all, list-reverse, list-tree |

## Test Stages

### Step 1: Dependency Check

Runs `kit deps-check` to verify all dependencies are installed:

```
Checking Kit toolkit dependencies...
✓ imagemagick - ImageMagick v7+ for image processing
✓ yt-dlp - YouTube/media downloader
✓ ffmpeg - Video/audio processing
✓ lsd - Enhanced file listing
✓ lsof - List open files (for killports)
```

**If dependencies are missing**, the test will show:
- Which packages are missing
- Installation commands for your platform (brew, apt, dnf, pacman, etc.)

### Step 2: Test Asset Setup

Automatically generates test assets:

```
Created test asset directories:
  tests/assets/images/
  tests/assets/video/
  tests/assets/audio/
```

**Generated test images:**
- `test_input_1920x1080.jpg` - Large image for optimization tests
- `test_input_800x600.jpg` - Medium image for resize tests
- `test_input_small.jpg` - Small image for thumbnail tests
- `test_input_large.jpg` - Extra large image
- `test photo with spaces.jpg` - Tests filename with spaces
- `test-photo(VR~quest).jpg` - Tests special character handling
- `test_input.webp` - WebP format for conversion tests

**Generated test video:**
- `test_input_video.mp4` - 5-second test video with audio (640x360)

### Step 3: Run Tests

Tests all toolkit functions using the `kit <command>` format (same as users use):

**Image Processing Tests:**
```bash
kit img-resize-width 400 test_input_800x600.jpg
kit img-optimize test_input_1920x1080.jpg
kit img-thumbnail 150 test_input_small.jpg
kit img-rename "test photo with spaces.jpg" --dry-run
# ... and 13 more image tests
```

**Media Processing Tests:**
```bash
kit compress-video test_input_video.mp4 -o test_input_video_compressed.mp4
kit remove-audio test_input_video.mp4
kit yt-download mp4 "https://youtu.be/1SBxsv_T_Jw"  # Downloads real video
# Processes downloaded: compress → mp3 → remove-audio
```

**System Utilities Tests:**
```bash
kit mklink source.txt link.txt
kit killports -h
kit update -h
kit uninstall -h
```

**Core Tests:**
```bash
kit -h                    # Main help
kit --list-categories     # List all categories
kit --search resize       # Search functions
```

### Step 4: Cleanup Prompt

After tests complete, shows generated files and offers cleanup:

```
Generated Test Files:
  test_input_800x600-resized.jpg
  test_input_small-resized.jpg
  test_input_1920x1080-optimized.jpg
  test_input_video_compressed.mp4
  test_input_video_noaudio.mp4
  ...

Test complete! Clean up test assets?
Options:
  [Y]es - Delete all test assets
  [N]o  - Keep assets for inspection
```

## YouTube Download Test

The suite downloads a real short video for comprehensive media testing:

- **URL:** `https://youtu.be/1SBxsv_T_Jw` (15-second Minecraft video)
- **Format:** MKV with embedded thumbnail and metadata
- **Processing chain:**
  1. Downloads video (creates `Minecraft in 15 seconds [1SBxsv_T_Jw].mkv`)
  2. Compresses the downloaded video
  3. Extracts audio to MP3
  4. Removes audio track

**Note:** This test requires network access. If offline, the test is gracefully skipped.

## File Naming Conventions

The test suite uses clear naming to distinguish input from output files:

**Input files** (test assets to be processed):
- `test_input_1920x1080.jpg` - Original large image
- `test_input_800x600.jpg` - Original medium image
- `test_input_small.jpg` - Original small image
- `test_input_video.mp4` - Original test video

**Output files** (results of processing):
- `test_input_800x600-resized.jpg` - Resized image output
- `test_input_1920x1080-optimized.jpg` - Optimized image output
- `test_input_small-resized.jpg` - Thumbnail output
- `test_input_video_compressed.mp4` - Compressed video output
- `test_input_video_noaudio.mp4` - Video without audio output
- `youtube_compressed.mp4` - Compressed YouTube video
- `<youtube_title>.mp3` - Extracted MP3 from YouTube video
- `<youtube_title>_noaudio.mp4` - YouTube video without audio

## Test Output

**All tests passing:**
```
✅ All tests passed!

Total:   39
Passed:  39
Failed:  0
Skipped: 0
```

**With failures:**
```
❌ Some tests failed

Total:   39
Passed:  35
Failed:  3
Skipped: 1
```

Failed tests are re-run with full output to help diagnose issues.

## Running Individual Tests

To test a specific function manually:

```bash
# From the tests/assets directory
cd tests/assets/images

# Test image resize
kit img-resize-width 400 test_input_800x600.jpg
ls -la test_input_800x600-resized.jpg

# Test optimization
kit img-optimize test_input_1920x1080.jpg
ls -la test_input_1920x1080-optimized.jpg
```

## Troubleshooting

### "Dependencies missing" error

Run `kit deps-install` to install missing dependencies, then re-run tests.

### YouTube test fails / skipped

- Check network connection
- Verify yt-dlp is installed: `command -v yt-dlp`
- Try manually: `kit yt-download mp4 "https://youtu.be/1SBxsv_T_Jw"`

### "Permission denied" errors

Ensure the test script is executable:
```bash
chmod +x tests/run-tests.sh
```

### Assets directory issues

The test suite automatically cleans and recreates assets. If you see errors:
```bash
rm -rf tests/assets
./tests/run-tests.sh
```

## Adding New Tests

When adding a new function to the toolkit, add corresponding tests to `run-tests.sh`:

1. **Help test:** Verify `-h` flag works
2. **Functional test:** Test actual operation with test assets
3. **Edge case test:** Test with special filenames if applicable

Example test addition:
```bash
# Help test
run_test "my-function: help works" "kit my-function -h"

# Functional test (if applicable)
cd "$ASSETS_DIR"
run_test "my-function: functional test" \
    "kit my-function test_input.txt && [[ -f 'expected_output.txt' ]]"
cd - >/dev/null
```

## Test Suite Files

```
tests/
├── run-tests.sh          # Main test runner
├── README.md             # This file
└── assets/               # Generated during test run (not in git)
    ├── images/           # Test images
    ├── video/            # Test videos
    └── audio/            # Test audio files
```
