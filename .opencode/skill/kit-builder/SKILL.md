---
name: kit-builder
description: Create new shell functions for Kit's Toolkit following established patterns. Use when adding functions, extending toolkit capabilities, creating utilities, or when user mentions "add function", "create function", "new kit function", or references kit_pattern.md. Handles pattern validation, category management, and testing.
---

# Kit Builder

Intelligently create production-ready shell functions for Kit's Toolkit following the standardized pattern in `kit_pattern.md`.

## When to Use This Skill

Use this skill when:
- User wants to add a new function to the toolkit
- Creating utilities that fit the toolkit pattern
- Converting scripts into toolkit functions
- User mentions: "add function", "create function", "new kit function"
- Extending toolkit capabilities with new features
- Building batch processing tools or utilities

## Core Workflow

### Phase 1: Understand Requirements

Ask focused questions to understand what needs to be built:

**Essential Questions:**
1. **What does this function do?** (1-2 sentence description)
2. **What are the required inputs?** (files, arguments, options)
3. **What should it produce?** (output files, messages, environment changes)
4. **Are there dependencies?** (external tools like imagemagick, ffmpeg, etc.)

**Context Questions (if needed):**
- Is this for single files or batch processing?
- Should it modify files in-place or create new ones?
- What are the success/failure conditions?
- Any special error handling needed?
- **Cross-platform considerations?** (macOS vs Linux differences)

### Phase 2: Determine Category

Choose the appropriate category based on function purpose:

**Decision Tree:**
```
Image processing (resize, convert, optimize, etc.)
  → Category: images.sh

Video/audio (convert, download, extract audio, etc.)
  → Category: media.sh

System utilities (file management, symlinks, editor shortcuts)
  → Category: system.sh

Navigation (directory shortcuts, environment management)
  → Category: aliases.sh

File listing (enhanced ls, tree views)
  → Category: lsd.sh

Dependency management (package installation, checking)
  → Category: deps.sh

None of the above with 3+ related functions
  → Create new category
```

**For New Categories:**
- Suggest category name (lowercase, descriptive)
- Create category file with proper header
- Add to categories.conf if it doesn't exist

### Phase 3: Design Function Interface

Plan the function signature and behavior:

**Function Name:**
- Format: `action-target` (e.g., `resize-img`, `convert-video`, `optimize-css`)
- Use lowercase with hyphens
- Start with action verb
- Be specific and descriptive

**Arguments:**
- List required arguments (must be provided)
- List optional arguments (with sensible defaults)
- Plan flag handling (-h, --help, custom flags)

**Exit Codes:**
- 0 = Success
- 1 = Error (file not found, operation failed)
- 2 = Invalid usage (missing required arguments)

### Phase 4: Implement Function

**Method 1: Use Template Generator (Recommended)**

Run the template generator script:
```bash
cd $KIT_EXT_DIR
./scripts/new-function.sh <category> <function-name> "<brief description>"
```

This creates a skeleton with:
- Category header updated
- Help block structure
- Input validation template
- Dependency checking framework
- Error handling pattern

Then fill in the implementation logic.

**Method 2: Manual Creation**

If template generator isn't suitable, create function manually following this structure:

```bash
function-name() {
    # REQUIRED: Help block (must be first)
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit function-name <required_arg> [optional_arg]
Description: Brief description of what this does (1-2 sentences)
Examples:
  kit function-name input.txt
  kit function-name input.txt --option value
EOF
        return 0
    fi

    # Input validation (exit 2 for invalid usage)
    if [[ -z "$1" ]]; then
        echo "Error: Missing required argument" >&2
        return 2
    fi

    # File existence check (if applicable)
    if [[ ! -f "$1" ]]; then
        echo "Error: File '$1' does not exist" >&2
        return 1
    fi

    # Dependency checking (if applicable)
    if ! command -v required_tool &> /dev/null; then
        echo "Error: required_tool not installed." >&2
        case "$(uname -s)" in
            Darwin)
                echo "Install with: brew install package" >&2
                ;;
            Linux)
                echo "Install with: sudo apt install package  # Debian/Ubuntu" >&2
                echo "            sudo dnf install package  # Fedora" >&2
                echo "            sudo pacman -S package     # Arch" >&2
                ;;
        esac
        return 1
    fi

    # Main implementation logic
    local input="$1"
    local output="${2:-default_output}"

    # Execute operation with error handling
    if ! operation_command "$input" "$output"; then
        echo "Error: Operation failed" >&2
        return 1
    fi

    # Success confirmation
    echo "✅ Successfully processed '$input' → '$output'"
    return 0
}
```

**Critical Requirements:**
- Help block with `-h` and `--help` support
- Input validation with exit code 2
- Error messages to stderr (`>&2`)
- Proper exit codes (0, 1, 2)
- Success confirmation message
- Dependency checks before use

### Phase 5: Update Category Header

Ensure the category file header lists the new function:

```bash
# category.sh - Category description
# Category: Category Display Name
# Description: What functions in this category do
# Dependencies: tool1, tool2 (or "none")
# Functions: func1, func2, func3, NEW_FUNCTION
```

Add the new function name to the Functions line.

### Phase 6: Validate Pattern Compliance

Run the pattern validator:
```bash
cd $KIT_EXT_DIR
./scripts/validate-pattern.sh functions/<category>.sh
```

**What it checks:**
- Category header present and complete
- Function listed in header
- Help block included
- Input validation present
- Error messages go to stderr
- Exit codes correct
- Dependency checks

**If validation fails:**
- Read error messages carefully
- Fix issues one by one
- Re-run validator until it passes

### Phase 7: Test Thoroughly

Create a comprehensive test plan:

**Test 1: Help Display**
```bash
source $KIT_EXT_DIR/loader.zsh
kit function-name -h
kit function-name --help
kit function-name  # no args (should show help)
```
Expected: Help text displays correctly

**Test 2: Invalid Usage**
```bash
kit function-name  # if args required
echo $?  # Should be 2
```
Expected: Error message to stderr, exit code 2

**Test 3: Missing File (if applicable)**
```bash
kit function-name /nonexistent/file.txt
echo $?  # Should be 1
```
Expected: File not found error, exit code 1

**Test 4: Missing Dependency (if applicable)**
```bash
# Temporarily rename the dependency
kit function-name valid-input.txt
```
Expected: Dependency error with install instructions

**Test 5: Success Case**
```bash
kit function-name valid-input.txt
echo $?  # Should be 0
```
Expected: Operation succeeds, confirmation message, exit code 0

**Test 6: Edge Cases**
```bash
# Test with various inputs
kit function-name empty-file.txt
kit function-name very-large-file.txt
kit function-name file-with-spaces.txt
kit function-name "file with special chars !@#.txt"
```

### Phase 8: Update Completions (Optional)

If the function needs custom tab completion:
```bash
cd $KIT_EXT_DIR
./scripts/generate-completions.sh
```

This auto-generates basic completion. For advanced completion (file type filters, option completion), manually edit `completions/_kit`.

### Phase 9: Document the Function

Add entry to project documentation if creating significant new functionality.

## Integration with Toolkit Scripts

**Available Scripts:**

1. **new-function.sh** - Template generator
   ```bash
   ./scripts/new-function.sh <category> <name> "<description>"
   ```

2. **validate-pattern.sh** - Pattern validator
   ```bash
   ./scripts/validate-pattern.sh functions/<category>.sh
   ```

3. **validate-shortcuts.sh** - Shortcuts validator
   ```bash
   ./scripts/validate-shortcuts.sh
   ```

4. **generate-completions.sh** - Completion generator
   ```bash
   ./scripts/generate-completions.sh
   ```

## Common Function Patterns

### Single File Processing

```bash
process-file() {
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit process-file <input>
Description: Process a single file
EOF
        return 0
    fi

    [[ -z "$1" ]] && { echo "Error: Missing input file" >&2; return 2; }
    [[ -f "$1" ]] || { echo "Error: File '$1' not found" >&2; return 1; }

    # Process the file
    echo "✅ Processed '$1'"
}
```

### Batch Processing

```bash
batch-process() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit batch-process <pattern>
Description: Process multiple files matching pattern
Examples:
  kit batch-process "*.txt"
  kit batch-process "images/*.jpg"
EOF
        return 0
    fi

    local pattern="${1:-*}"
    local count=0

    for file in $pattern; do
        [[ -f "$file" ]] || continue
        # Process file
        ((count++))
    done

    echo "✅ Processed $count files"
}
```

### With Options/Flags

```bash
process-with-options() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit process-with-options [options] <input>
Options:
  -q, --quality NUM    Quality level (default: 80)
  -o, --output FILE    Output file (default: input + suffix)
EOF
        return 0
    fi

    local quality=80
    local output=""

    # Parse options
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
            *)
                local input="$1"
                shift
                ;;
        esac
    done

    [[ -z "$input" ]] && { echo "Error: Missing input" >&2; return 2; }

    # Process with options
    echo "✅ Processed with quality=$quality"
}
```

### Cross-Platform Compatibility

When writing functions that work on both macOS and Linux:

```bash
# OS Detection helper
_kit_detect_os() {
    case "$(uname -s)" in
        Darwin)  echo "macos" ;;
        Linux)   echo "linux" ;;
        *)       echo "unknown" ;;
    esac
}

# Platform-specific commands
cross-platform-function() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit cross-platform-function <input>
Description: Works on both macOS and Linux
Platform support:
  - macOS: Uses native tools
  - Linux: Uses equivalent tools
EOF
        return 0
    fi

    local input="$1"
    local os="$(_kit_detect_os)"

    # Platform-specific logic
    case "$os" in
        macos)
            # macOS-specific implementation
            ;;
        linux)
            # Linux-specific implementation
            ;;
    esac

    echo "✅ Processed on $os"
}
```

**Common cross-platform considerations:**
- **File paths**: Use `$HOME` instead of `~` in scripts
- **Commands**: `realpath` may not exist on macOS (use Perl or zsh fallback)
- **Install instructions**: Use `_kit_get_package_install_cmd()` from deps.sh for consistent install messages
- **Editor integration**: macOS uses `open -a AppName`, Linux uses direct command
- **Package managers**: Support brew (macOS), apt, dnf, yum, pacman, zypper (Linux)

**Cross-platform dependency helper functions** (available in deps.sh):
```bash
# Detect OS: returns "macos", "linux", or "unknown"
_kit_detect_os

# Detect package manager: returns "brew", "apt", "dnf", "yum", "pacman", "zypper", or "none"
_kit_detect_package_manager

# Get platform-specific install command for a package
_kit_get_package_install_cmd <package_name>

# Example usage in dependency check:
if ! command -v required_tool &> /dev/null; then
    echo "Error: required_tool not installed." >&2
    local install_cmd
    install_cmd=$(_kit_get_package_install_cmd "package_name")
    # Check if output doesn't start with "Error"
    if [[ "$install_cmd" != Error:* ]]; then
        echo "Install with: $install_cmd" >&2
    else
        echo "$install_cmd" >&2
    fi
    return 1
fi
```

## Category Management

### When to Create New Category

Create a new category when:
- You have 3+ related functions
- Functions share common dependencies
- Distinct purpose from existing categories
- Likely to grow with more functions

### Creating New Category

1. **Create category file:**
   ```bash
   cat > functions/new-category.sh << 'EOF'
   # new-category.sh - Description of category
   # Category: Display Name
   # Description: What these functions do
   # Dependencies: tool1, tool2 (or "none")
   # Functions: function1, function2

   function1() {
       # Implementation
   }
   EOF
   ```

2. **Add to categories.conf (if needed):**
   ```bash
   echo "new-category:Display Name:Description" >> categories.conf
   ```

3. **Reload toolkit:**
   ```bash
   source loader.zsh
   ```

## Troubleshooting

**"Function already exists"**
- Check existing functions: `kit -h`
- Choose different name
- Consider if function should be enhanced instead

**"Pattern validation fails"**
- Read error messages carefully
- Common issues:
  - Missing help block
  - No input validation
  - Wrong exit codes
  - Errors not to stderr
  - Function not in category header

**"Dependency not found"**
- Check if tool is installed: `command -v tool_name`
- Suggest Homebrew install: `brew install package`
- Include install command in error message

**"Function not available after creation"**
- Reload toolkit: `source $KIT_EXT_DIR/loader.zsh`
- Check syntax errors: `bash -n functions/category.sh`
- Verify function name matches in file and header

## Quality Checklist

Before considering the function complete:

- [ ] Function name follows convention (lowercase-with-hyphens)
- [ ] Help block complete with usage, description, examples
- [ ] `-h` and `--help` flags work
- [ ] Required argument validation (exit 2 if missing)
- [ ] File existence checks (exit 1 if not found)
- [ ] Dependency checks with install instructions
- [ ] Error messages go to stderr (`>&2`)
- [ ] Success messages confirm what was done
- [ ] Exit codes correct (0, 1, 2)
- [ ] Function listed in category header
- [ ] Pattern validation passes
- [ ] All test cases pass
- [ ] Works with files containing spaces/special chars

## Best Practices

1. **Keep functions focused** - One function, one purpose
2. **Validate early** - Check inputs before processing
3. **Fail gracefully** - Clear error messages with context
4. **Be explicit** - Better verbose than ambiguous
5. **Test edge cases** - Empty files, special characters, large files
6. **Document examples** - Show real usage, not placeholders
7. **Check dependencies** - Don't assume tools are installed
8. **Confirm success** - Tell user what happened
9. **Use consistent patterns** - Follow existing function style
10. **Think about users** - Make help text useful

## Quick Reference

**Create new function:**
```bash
cd $KIT_EXT_DIR
./scripts/new-function.sh images resize-png "Resize PNG files"
# Edit functions/images.sh to implement logic
./scripts/validate-pattern.sh functions/images.sh
source loader.zsh
kit resize-png -h
```

**Test function:**
```bash
kit function-name -h          # Help works?
kit function-name             # Shows usage?
kit function-name bad.txt     # Error handling?
kit function-name good.txt    # Success?
echo $?                       # Exit code correct?
```

**Update after changes:**
```bash
source $KIT_EXT_DIR/loader.zsh
```

---

This skill ensures all new toolkit functions are:
- ✅ Pattern-compliant
- ✅ Well-documented
- ✅ Thoroughly tested
- ✅ Error-resilient
- ✅ User-friendly
