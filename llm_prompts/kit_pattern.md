# Kit's Toolkit Extension Pattern

## Overview

This document provides a comprehensive template for creating new extensions for Kit's Toolkit. AI agents should follow this pattern exactly to ensure consistency and compatibility.

## Core Principles

1. **Function-first Design**: Each extension is a single shell function
2. **Self-documenting**: Every function includes built-in help
3. **Error-resilient**: Comprehensive input validation and error handling
4. **Consistent Interface**: Follow established naming and structure conventions

## Function Template

```bash
# Function Name: Use lowercase with hyphens (e.g., process-files, convert-format)
function-name() {
    # REQUIRED: Help block - always first
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit function-name <required_args> [optional_args]
Description: Brief description of what the function does (1-2 sentences)
Examples:
  kit function-name arg1 arg2    # Example usage
  kit function-name --option value arg1
EOF
        return 0
    fi

    # Input validation - check required arguments first
    if [[ -z "$1" ]]; then
        echo "Error: Missing required argument" >&2
        return 2
    fi

    # File/directory validation if applicable
    if [[ ! -f "$1" ]]; then
        echo "Error: File '$1' does not exist" >&2
        return 1
    fi

    # Dependency checking
    if ! command -v required_command &> /dev/null; then
        echo "Error: required_command not installed. Install with: brew install package" >&2
        return 1
    fi

    # Main logic with error handling
    if ! command_that_can_fail; then
        echo "Error: Operation failed" >&2
        return 1
    fi

    # Success feedback
    echo "Operation completed successfully"
}
```

## Naming Conventions

### Function Names
- **Format**: lowercase-with-hyphens (e.g., `resize-img`, `convert-bulk`, `git-status`)
- **Action-first**: Start with verb describing the primary action
- **Descriptive**: Clearly indicate function purpose
- **Consistent**: Use established patterns from existing functions

### Examples
- ✅ `resize-img`, `upscale-img`, `optimize-img` (image operations)
- ✅ `convert-bulk`, `format-files` (batch operations)
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
# Functions: resize-img, upscale-img, optimize-img, convert-bulk, convert-heic, optimize-to-webp
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
- [ ] `kit function-name` (no args) shows usage
- [ ] Missing required args return exit code 2
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
- [ ] Input validation implemented
- [ ] Error messages go to stderr with appropriate codes
- [ ] Dependencies checked before use
- [ ] Code follows shell best practices
- [ ] Manual testing passes all scenarios
- [ ] Pattern validation passes (`./scripts/validate-pattern.sh`)

## Development Tools

The toolkit includes helper scripts to make development easier:

### Template Generator
Generate a new function template:
```bash
./scripts/new-function.sh images resize-png "Resize PNG files"
```

Creates a skeleton function in `functions/images.sh` with all required sections.

### Pattern Validator
Check if functions follow this pattern:
```bash
./scripts/validate-pattern.sh functions/images.sh
```

Verifies:
- Category header present
- Help block included
- Input validation present
- Error handling correct
- Exit codes appropriate

### Completion Generator
Auto-generate tab completion:
```bash
./scripts/generate-completions.sh
```

Scans all functions and updates the completion script.

## Quick Reference

### Creating a New Function

1. **Generate template:**
   ```bash
   ./scripts/new-function.sh category function-name "Description"
   ```

2. **Edit `functions/category.sh`:**
   - Replace placeholder with implementation
   - Ensure all validation is included
   - Test the function

3. **Validate:**
   ```bash
   ./scripts/validate-pattern.sh functions/category.sh
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
