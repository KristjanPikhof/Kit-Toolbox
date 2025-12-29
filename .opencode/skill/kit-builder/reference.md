# Kit Builder - Quick Reference

Quick reference for common scenarios, patterns, and troubleshooting.

## Workflow Quick Reference

### Standard Function Creation Flow

```bash
# 1. Generate template
cd $KIT_EXT_DIR
./scripts/new-function.sh <category> <function-name> "<description>"

# 2. Edit the function (add implementation logic)
$EDITOR functions/<category>.sh

# 3. Validate pattern compliance
./scripts/validate-pattern.sh functions/<category>.sh

# 4. Load and test
source loader.zsh
kit <function-name> -h
kit <function-name> <test-input>

# 5. Update completions (if needed)
./scripts/generate-completions.sh
```

---

## Pattern Templates

### Minimal Function Template

```bash
my-function() {
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit my-function <arg>
Description: What it does
EOF
        return 0
    fi

    [[ -z "$1" ]] && { echo "Error: Missing arg" >&2; return 2; }

    # Implementation here

    echo "✅ Success"
}
```

### File Processing Template

```bash
process-file() {
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit process-file <input> [output]
Description: Process a file
Examples:
  kit process-file input.txt
  kit process-file input.txt output.txt
EOF
        return 0
    fi

    # Validation
    [[ -z "$1" ]] && { echo "Error: Missing input" >&2; return 2; }
    [[ -f "$1" ]] || { echo "Error: File not found: $1" >&2; return 1; }

    # Dependency check
    command -v tool &>/dev/null || {
        echo "Error: tool not installed. Install: brew install tool" >&2
        return 1
    }

    # Process
    local input="$1"
    local output="${2:-${input%.*}_processed.${input##*.}}"

    if ! tool "$input" -o "$output"; then
        echo "Error: Processing failed" >&2
        return 1
    fi

    echo "✅ Processed '$input' → '$output'"
}
```

### Batch Processing Template

```bash
batch-process() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit batch-process [pattern]
Description: Process multiple files
Examples:
  kit batch-process "*.txt"
  kit batch-process
EOF
        return 0
    fi

    local pattern="${1:-*}"
    local count=0
    local processed=0

    for file in $pattern; do
        [[ -f "$file" ]] || continue
        ((count++))

        if process_single_file "$file"; then
            ((processed++))
            echo "Processed: $(basename "$file")"
        else
            echo "Failed: $(basename "$file")" >&2
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo "No files found matching pattern"
        return 0
    fi

    echo "✅ Processed $processed/$count files"
}
```

### Options/Flags Template

```bash
function-with-options() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit function-with-options [options] <input>
Options:
  -q, --quality NUM    Quality (default: 80)
  -o, --output FILE    Output file
  -v, --verbose        Verbose mode
Examples:
  kit function-with-options input.txt
  kit function-with-options -q 95 -o output.txt input.txt
EOF
        return 0
    fi

    local quality=80
    local output=""
    local verbose=false
    local input=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -q|--quality)
                quality="$2"
                shift 2
                ;;
            -o|--output)
                output="$2"
                shift 2
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            *)
                input="$1"
                shift
                ;;
        esac
    done

    [[ -z "$input" ]] && { echo "Error: Missing input" >&2; return 2; }

    # Use options in processing
    $verbose && echo "Quality: $quality"

    echo "✅ Processed with quality=$quality"
}
```

---

## Common Validation Patterns

### Required Argument

```bash
if [[ -z "$1" ]]; then
    echo "Error: Missing required argument" >&2
    return 2
fi
```

### File Exists

```bash
if [[ ! -f "$1" ]]; then
    echo "Error: File '$1' does not exist" >&2
    return 1
fi
```

### Directory Exists

```bash
if [[ ! -d "$1" ]]; then
    echo "Error: Directory '$1' does not exist" >&2
    return 1
fi
```

### File is Readable

```bash
if [[ ! -r "$1" ]]; then
    echo "Error: File '$1' is not readable" >&2
    return 1
fi
```

### Valid Format/Extension

```bash
if [[ ! "$1" =~ \.(jpg|png|gif)$ ]]; then
    echo "Error: File must be JPG, PNG, or GIF" >&2
    return 2
fi
```

### Numeric Value

```bash
if [[ ! "$quality" =~ ^[0-9]+$ ]] || [[ $quality -lt 1 || $quality -gt 100 ]]; then
    echo "Error: Quality must be 1-100" >&2
    return 2
fi
```

### Command/Dependency

```bash
if ! command -v tool &>/dev/null; then
    echo "Error: tool not installed. Install with: brew install package" >&2
    return 1
fi
```

---

## Error Handling Patterns

### Simple Error Exit

```bash
[[ -f "$file" ]] || { echo "Error: File not found" >&2; return 1; }
```

### Error with Cleanup

```bash
if ! operation; then
    echo "Error: Operation failed" >&2
    rm -f "$temp_file"  # Cleanup
    return 1
fi
```

### Trap for Cleanup

```bash
temp_file=$(mktemp) || { echo "Error: Cannot create temp file" >&2; return 1; }
trap 'rm -f "$temp_file"' EXIT

# Rest of function...
```

### Multiple Error Conditions

```bash
if ! command -v tool &>/dev/null; then
    echo "Error: tool not installed" >&2
    return 1
elif [[ ! -f "$input" ]]; then
    echo "Error: Input file not found" >&2
    return 1
elif [[ ! -w "$(dirname "$output")" ]]; then
    echo "Error: Output directory not writable" >&2
    return 1
fi
```

---

## Category File Header Format

Every category file must have this header:

```bash
# category-name.sh - Brief description
# Category: Display Name
# Description: Detailed description of what functions in this category do
# Dependencies: tool1, tool2, tool3 (or "none")
# Functions: func1, func2, func3, func4
```

**Example:**

```bash
# images.sh - Image manipulation utilities
# Category: Image Processing
# Description: ImageMagick-based image manipulation and optimization utilities
# Dependencies: imagemagick
# Functions: img-resize, img-optimize, img-convert, img-thumbnail
```

---

## Exit Code Standards

**ALWAYS use these exit codes:**

- **0** = Success (operation completed successfully)
- **1** = Runtime error (file not found, operation failed, dependency missing)
- **2** = Usage error (missing required arguments, invalid format)

**Examples:**

```bash
# Success
echo "✅ Success"
return 0

# Missing required argument (usage error)
echo "Error: Missing input file" >&2
return 2

# File not found (runtime error)
echo "Error: File '$1' not found" >&2
return 1

# Dependency missing (runtime error)
echo "Error: tool not installed" >&2
return 1
```

---

## Testing Checklist

```bash
# Test 1: Help displays
kit function-name -h
kit function-name --help

# Test 2: No arguments (should show help or error)
kit function-name

# Test 3: Invalid usage (exit code 2)
kit function-name
echo $?  # Should be 2

# Test 4: File not found (exit code 1)
kit function-name /nonexistent/file
echo $?  # Should be 1

# Test 5: Success case (exit code 0)
kit function-name valid-input.txt
echo $?  # Should be 0

# Test 6: Edge cases
kit function-name "file with spaces.txt"
kit function-name empty-file.txt
kit function-name very-large-file.txt
```

---

## Common Issues & Solutions

### Issue: Function not found after creation

**Solution:**
```bash
# Reload the toolkit
source $KIT_EXT_DIR/loader.zsh

# Or restart your shell
exec zsh
```

### Issue: Pattern validation fails

**Common causes:**
- Missing help block
- Function not listed in category header
- No input validation
- Errors not going to stderr
- Wrong exit codes

**Solution:**
```bash
# Read validation output carefully
./scripts/validate-pattern.sh functions/category.sh

# Fix issues one by one
# Re-run validation
```

### Issue: Help block not displaying

**Cause:** Help condition wrong

**Fix:**
```bash
# CORRECT
if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then

# WRONG (missing -z check for no args)
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
```

### Issue: Errors not visible

**Cause:** Not redirecting to stderr

**Fix:**
```bash
# CORRECT
echo "Error: Something failed" >&2

# WRONG
echo "Error: Something failed"
```

### Issue: Function exists but shows "command not found"

**Cause:** Function name doesn't match in header

**Fix:**
Check that function name in:
1. Function definition: `my-function() {`
2. Category header Functions list: `# Functions: ..., my-function`

### Issue: Tab completion not working

**Solution:**
```bash
# Regenerate completions
cd $KIT_EXT_DIR
./scripts/generate-completions.sh

# Reload shell
exec zsh
```

---

## Dependency Detection

### Common Tools and Packages

| Tool | Homebrew Package | Check Command |
|------|------------------|---------------|
| ImageMagick | `brew install imagemagick` | `command -v magick` |
| FFmpeg | `brew install ffmpeg` | `command -v ffmpeg` |
| yt-dlp | `brew install yt-dlp` | `command -v yt-dlp` |
| jq | `brew install jq` | `command -v jq` |
| ripgrep | `brew install ripgrep` | `command -v rg` |
| fd | `brew install fd` | `command -v fd` |
| bat | `brew install bat` | `command -v bat` |
| lsd | `brew install lsd` | `command -v lsd` |

### Dependency Check Template

```bash
# Single dependency
if ! command -v tool &>/dev/null; then
    echo "Error: tool not installed. Install with: brew install package" >&2
    return 1
fi

# Multiple dependencies
for tool in tool1 tool2 tool3; do
    if ! command -v "$tool" &>/dev/null; then
        echo "Error: $tool not installed" >&2
        return 1
    fi
done
```

---

## File Output Patterns

### Same directory, modified name

```bash
local input="$1"
local output="${input%.*}_processed.${input##*.}"
# input.txt → input_processed.txt
```

### Different extension

```bash
local output="${input%.*}.jpg"
# image.png → image.jpg
```

### Output directory

```bash
local output_dir="${2:-./output}"
mkdir -p "$output_dir"
local output="$output_dir/$(basename "$input")"
```

### Timestamped output

```bash
local timestamp=$(date +%Y%m%d_%H%M%S)
local output="${input%.*}_${timestamp}.${input##*.}"
# file.txt → file_20240115_143022.txt
```

---

## Progress Indication

### Simple counter

```bash
echo "Processing $count files..."
for file in *.txt; do
    process "$file"
done
echo "✅ Processed $count files"
```

### Progress with current/total

```bash
local total=${#files[@]}
local current=1
for file in "${files[@]}"; do
    echo "[$current/$total] Processing $(basename "$file")..."
    process "$file"
    ((current++))
done
```

### Inline progress (overwrites line)

```bash
local current=1
for file in *.txt; do
    printf "\rProcessing %d/%d: %-50s" "$current" "$total" "$(basename "$file")"
    process "$file"
    ((current++))
done
printf "\n"
```

---

## Best Practices Summary

1. **Always validate inputs** before processing
2. **Check dependencies** before using them
3. **Use proper exit codes** (0, 1, 2)
4. **Send errors to stderr** (`>&2`)
5. **Provide clear success messages**
6. **Include installation instructions** in error messages
7. **Handle edge cases** (empty files, spaces in names, special characters)
8. **Test thoroughly** before considering complete
9. **Document with examples** in help text
10. **Follow naming conventions** (lowercase-with-hyphens)

---

## Quick Command Reference

```bash
# Create function
./scripts/new-function.sh images my-func "Description"

# Validate
./scripts/validate-pattern.sh functions/images.sh

# Reload toolkit
source $KIT_EXT_DIR/loader.zsh

# Test
kit my-func -h
kit my-func test-input

# Update completions
./scripts/generate-completions.sh

# List all functions
kit -h

# Search functions
kit --search keyword

# List categories
kit --list-categories
```

---

This reference provides quick access to the most common patterns and solutions when building toolkit functions.
