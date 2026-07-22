# Kit's Toolkit Extension Pattern

## Overview

This document provides a comprehensive template for creating new extensions for Kit's Toolkit. AI agents should follow this pattern exactly to ensure consistency, security, and compatibility.

## Core Principles

1. **Function-first Design**: Each extension is a single shell function
2. **Self-documenting**: Every function includes built-in help
3. **Error-resilient**: Comprehensive input validation and error handling
4. **Security-first**: Semantic validation, quoted paths, array-based execution, and safe output installation
5. **Consistent Interface**: Follow established naming and structure conventions

## Function Template

```bash
# Function Name: Use lowercase with hyphens (e.g., process-files, convert-format)
function-name() {
    local force=false
    local input=""

    # Parse arguments first (before validation)
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit function-name [options] <required_args>
Description: Brief description of what the function does (1-2 sentences)
Options:
  -f, --force    Overwrite output file if it exists
Examples:
  kit function-name arg1              # Basic usage
  kit function-name --force arg1     # Overwrite existing output
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                fi
                shift
                ;;
        esac
    done

    # Input validation - check required arguments first
    if [[ -z "$input" ]]; then
        echo "Error: Missing required argument" >&2
        return 2
    fi

    # File validation
    if [[ ! -f "$input" ]]; then
        echo "Error: File '$input' does not exist" >&2
        return 1
    fi

    # Dependency checking
    if ! command -v required_command &> /dev/null; then
        echo "Error: required_command not installed. Install with: brew install package" >&2
        return 1
    fi

    # Determine output file
    local output="${input%.*}_processed.${input##*.}"

    if [[ "${input:A}" == "${output:A}" ]]; then
        echo "Error: Input and output must be different files" >&2
        return 2
    fi

    if [[ -e "$output" && "$force" != true ]]; then
        echo "Error: Output file '$output' already exists. Use --force to overwrite." >&2
        return 1
    fi

    # Write to a sibling temporary path. Keeping the final filename at the end
    # preserves the extension for tools that infer the container from it.
    local output_dir="${output:h}"
    local output_name="${output:t}"
    local temporary="$output_dir/.kit-tmp.$$.$RANDOM.$output_name"

    if ! command_that_can_fail "$input" "$temporary" || [[ ! -f "$temporary" ]]; then
        rm -f -- "$temporary"
        echo "Error: Operation failed" >&2
        return 1
    fi

    if [[ "$force" == true ]]; then
        mv -f -- "$temporary" "$output" || { rm -f -- "$temporary"; return 1; }
    elif ! mv -n -- "$temporary" "$output" || [[ -e "$temporary" ]]; then
        rm -f -- "$temporary"
        echo "Error: Refusing to replace output created during processing" >&2
        return 1
    fi

    # Success feedback
    echo "✅ Processed: $output"
    return 0
}
```

## Naming Conventions

### Function Names
- **Format**: lowercase-with-hyphens (e.g., `img-resize`, `convert-to-mp3`, `pdf-merge`)
- **Consistent family**: Match the prefix or action style already used by the category
- **Descriptive**: Clearly indicate function purpose
- **Consistent**: Use established patterns from existing functions

### Examples
- ✅ `img-resize`, `img-thumbnail`, `img-optimize` (image operations)
- ✅ `convert-to-mp3`, `compress-video`, `remove-audio` (media operations)
- ❌ `imgresize`, `ResizeImage` (wrong case/underscores)
- ❌ `do-stuff`, `process` (too vague)

## File Organization

### Location
- **Directory**: `$KIT_EXT_DIR/functions/`
- **Naming**: `category.sh` (e.g., `images.sh`, `git-tools.sh`, `system.sh`)
- **Grouping**: Related functions in single files

### File Structure
```bash
# filename.sh - Brief description of function category
# Category: Display Name of Category
# Description: What these functions do
# Dependencies: tool1, tool2 (or "none")
# Functions: function1, function2, function3

function1() {
    # Implementation...
}

function2() {
    # Implementation...
}
```

### Category Header Format

Each function file MUST include a category header with these fields:

```bash
# Category: Category Name
# Description: What functions in this file do
# Dependencies: comma-separated list (e.g., "imagemagick, ffmpeg" or "none")
# Functions: func1, func2, func3
```

This header is used for:
- Auto-discovery and categorization
- Help system grouping
- Category listing (`kit --list-categories`)
- Documentation generation

### Example Category Header

```bash
# images.sh - Image manipulation utilities
# Category: Image Processing
# Description: ImageMagick-based image manipulation and optimization utilities
# Dependencies: imagemagick
# Functions: img-resize, img-thumbnail, img-optimize, img-convert, img-optimize-to-webp
```

## Error Handling Standards

### Exit Codes
- **0**: Success
- **1**: General error (file not found, operation failed)
- **2**: Invalid usage (missing arguments, wrong format)

### Error Messages
- **Format**: `echo "Error: Description" >&2`
- **Specific**: Include relevant details (filenames, values)
- **Actionable**: Suggest solutions when possible
- **Consistent**: Follow established patterns

### Examples
```bash
# Good: Specific and actionable
echo "Error: File '$filename' not found in current directory" >&2
echo "Error: Invalid format '$format'. Use 'jpg' or 'png'" >&2
echo "Error: ImageMagick required. Install with: brew install imagemagick" >&2

# Bad: Generic or unclear
echo "Error" >&2
echo "Failed" >&2
echo "Something went wrong" >&2
```

## Input Validation Patterns

### Required Arguments
```bash
if [[ -z "$1" ]]; then
    echo "Error: Missing input file" >&2
    return 2
fi
```

### File Existence
```bash
if [[ ! -f "$1" ]]; then
    echo "Error: Input file '$1' does not exist" >&2
    return 1
fi
```

### Directory Existence
```bash
if [[ ! -d "$1" ]]; then
    echo "Error: Directory '$1' does not exist" >&2
    return 1
fi
```

### Command Dependencies
```bash
if ! command -v magick &> /dev/null; then
    echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
    return 1
fi
```

### Numeric Validation
```bash
# Validate syntax before arithmetic, then force decimal interpretation.
if [[ ! "$port" =~ ^[0-9]+$ ]]; then
    echo "Error: Port must be a number" >&2
    return 2
fi
local port_decimal=$((10#$port))
if [[ "$port_decimal" -lt 1 || "$port_decimal" -gt 65535 ]]; then
    echo "Error: Port must be 1-65535" >&2
    return 2
fi
```

### Safe Path Handling
```bash
# Safely quoted filenames may contain spaces, leading dots, and shell characters.
[[ -f "$filename" ]] || { echo "Error: File not found: $filename" >&2; return 1; }
local -a cmd=(required_tool -- "$filename")
"${cmd[@]}"
```

## Security Best Practices

**CRITICAL: All functions MUST follow these security patterns:**

### 1. Safer Error Handling Pattern

```bash
# GOOD - Direct negation, exit code tied to command
if ! ffmpeg "${cmd[@]}" 2>/dev/null; then
    echo "Error: Processing failed" >&2
    return 1
fi

# BAD - Fragile, can break if code is added
ffmpeg "${cmd[@]}" 2>/dev/null
if [[ $? -ne 0 ]]; then
    echo "Error: Processing failed" >&2
    return 1
fi
```

### 2. Array-Based Command Building

```bash
# GOOD - Use array to prevent injection
local -a cmd=(ffmpeg -i "$input" -c:v libx264 -crf "$crf" "$output")
"${cmd[@]}"

# BAD - String concatenation is vulnerable
local cmd="ffmpeg -i $input -c:v libx264 -crf $crf $output"
eval "$cmd"  # NEVER use eval with user input
```

### 3. Atomic Output Installation

```bash
# Never delete the destination before processing. Write and validate a sibling
# temporary file, then use mv -n for normal mode or mv -f for explicit force.
# Re-check that mv -n consumed the temporary file to detect a concurrent writer.
```

### 4. Confined Path Validation

```bash
# Only enforce containment when the function promises to stay within a root.
# Resolve both paths, then compare the canonical candidate with the canonical
# allowed root. Do not reject ordinary ../ segments for unconstrained file tools.
```

### 5. Shell Identifier Validation

```bash
# Validate function/variable names (for dynamic generation)
_kit_validate_shell_identifier() {
    local name="$1"
    # Valid: start with letter/underscore, then alphanumeric/underscore
    [[ "$name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]
}
```

## Help Documentation Standards

### Required Elements
1. **Usage line**: Clear syntax with required/optional args
2. **Description**: What the function does (1-2 sentences)
3. **Examples**: 1-3 practical usage examples

### Format
```bash
cat << EOF
Usage: kit function-name <required> [optional]
Description: Brief description of functionality
Examples:
  kit function-name arg1 arg2
  kit function-name --flag value
EOF
```

### Best Practices
- **Clear syntax**: Use `<>` for required, `[]` for optional
- **Concrete examples**: Real values, not placeholders
- **Progressive complexity**: Start simple, add advanced examples
- **Realistic scenarios**: Show common use cases

## Testing Requirements

### Manual Testing Checklist
- [ ] `kit function-name -h` shows help
- [ ] `kit function-name -h` and `--help` show usage
- [ ] Missing required args return exit code 2, unless no-argument help is explicitly part of the interface
- [ ] Invalid inputs return appropriate errors
- [ ] Successful execution returns 0 and shows confirmation
- [ ] Dependencies properly checked

### Edge Cases to Test
- Empty arguments
- Non-existent files/directories
- Permission issues
- Network failures (if applicable)
- Invalid formats/values

## Common Patterns

### File Processing Loop
```bash
process_files() {
    local input_dir="$1"
    local output_dir="$2"

    mkdir -p "$output_dir"

    for file in "$input_dir"/*; do
        if [[ -f "$file" ]]; then
            process_single_file "$file" "$output_dir"
        fi
    done
}
```

### Progress Indication
```bash
show_progress() {
    local current="$1"
    local total="$2"
    local item="$3"
    printf "\rProcessing %d/%d: %s" "$current" "$total" "$item" >&2
}
```

### Temporary Files
```bash
local temp_file
temp_file=$(mktemp) || {
    echo "Error: Could not create temporary file" >&2
    return 1
}
trap 'rm -f "$temp_file"' EXIT
```

### Argument Parsing with Options
```bash
process_with_options() {
    local force=false
    local quality=80
    local input=""

    # Parse arguments first
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -q|--quality)
                quality="$2"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
                ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                fi
                shift
                ;;
        esac
    done

    # Validate after parsing
    [[ -z "$input" ]] && { echo "Error: Missing input" >&2; return 2; }

    # Rest of function...
}
```

### Complex Command with Arrays (Safe)
```bash
# Build command as array (prevents injection)
local -a ffmpeg_cmd=(ffmpeg -i "$input" -c:v libx264 -crf "$crf")

# Add optional arguments conditionally
if [[ "$width" != "-1" ]]; then
    local scale_filter="scale='trunc(min(iw,$width)/2)*2':-2"
    ffmpeg_cmd+=(-vf "$scale_filter")
fi

ffmpeg_cmd+=(-movflags +faststart "$output")

# Execute safely
if ! ffmpeg "${ffmpeg_cmd[@]}" 2>/dev/null; then
    echo "Error: Processing failed" >&2
    return 1
fi
```

## Development Workflow

### 1. Planning
- Define function purpose and interface
- Identify required dependencies
- Plan input validation and error cases

### 2. Implementation
- Follow the template structure
- Add comprehensive error handling
- Include detailed help documentation

### 3. Testing
- Test all help scenarios
- Verify error conditions
- Confirm successful operation
- Test edge cases

### 4. Documentation
- Update function file header
- Add inline comments for complex logic
- Update any relevant README sections

## AI Development Guidelines

### When creating new extensions:

1. **Analyze existing patterns**: Study similar functions in the codebase
2. **Follow naming conventions**: Match style of related functions
3. **Include all validation**: Never assume valid input
4. **Test thoroughly**: Verify all error paths and success cases
5. **Document clearly**: Help text should be comprehensive but concise

### Quality Checklist:
- [ ] Function follows naming conventions
- [ ] Category header updated with new function name
- [ ] Help block present and comprehensive
- [ ] Input validation implemented (required args, file existence, type checking)
- [ ] **Safe path handling** (quoted expansions; spaces, leading dots, and shell characters tested)
- [ ] Error messages go to stderr with appropriate codes
- [ ] **Safer error handling** (use `if ! command` not `$?`)
- [ ] **Atomic output handling** (no pre-delete; failed force keeps the original; no-force detects races)
- [ ] Dependencies checked before use
- [ ] **Array-based command building** for complex commands
- [ ] Code follows shell best practices
- [ ] Manual testing passes all scenarios
- [ ] Pattern validation passes (`zsh scripts/validate-pattern.sh`)

## Development Tools

The toolkit includes helper scripts to make development easier:

### Template Generator
Generate a new function template:
```bash
bash scripts/new-function.sh images resize-png "Resize PNG files"
```

Creates a skeleton function in `functions/images.sh` with all required sections.

### Pattern Validator
Check if functions follow this pattern:
```zsh
zsh scripts/validate-pattern.sh functions/images.sh
```

Verifies:
- Category header present
- Help block included
- Input validation present
- Error handling correct
- Exit codes appropriate

### Completion System Verifier
Verify the dynamic completion system is working:
```bash
./scripts/generate-completions.sh
```

**Note:** The completion system is FULLY DYNAMIC. No regeneration needed!
It automatically discovers:
- All functions from `functions/*.sh` (via `# Functions:` headers)
- All editor shortcuts from `editor.conf`
- All navigation shortcuts from `shortcuts.conf`

**Loader/config behavior to preserve:**
- Navigation and editor shortcuts are generated as direct shell functions, but those functions delegate to internal handlers instead of embedding target paths or editor commands.
- Valid `shortcuts.conf` and `editor.conf` changes are picked up after reloading Kit. Removed entries are unregistered on re-source. Do not make generated functions re-read config files on each invocation.
- Setting `KIT_AUTO_SHORTCUTS=false` or `KIT_AUTO_EDITORS=false` before re-sourcing removes kit-created shortcut/editor functions for that session.
- Existing user-defined functions win over generated shortcuts/editors, with a warning.
- Editor commands are parsed into argv safely via `lib/kit-core.zsh`. Do not use `eval`; do not support shell operators, command substitution, or environment-variable expansion in `editor.conf` commands.
- Config descriptions may contain `|` characters; use `lib/kit-core.zsh` parsers instead of naive `IFS='|'` splitting.

Simply reload your shell after adding new functions:
```bash
source ~/.zshrc
```

## Quick Reference

### Creating a New Function

1. **Generate template:**
   ```bash
   bash scripts/new-function.sh category function-name "Description"
   ```

2. **Edit `functions/category.sh`:**
   - Replace placeholder with implementation
   - Ensure all validation is included
   - Test the function

3. **Validate:**
   ```zsh
   zsh scripts/validate-pattern.sh functions/category.sh
   ```

4. **Update completions:**
   ```bash
   ./scripts/generate-completions.sh
   ```

### Testing a Function

```bash
# Load functions
source loader.zsh

# Test help
kit my-function -h

# Test with missing args
kit my-function  # Should return exit code 2

# Test with invalid input
kit my-function nonexistent.txt  # Should return 1

# Test success
kit my-function valid.txt  # Should return 0
```

This pattern ensures all Kit's Toolkit extensions maintain consistency, reliability, and usability.
