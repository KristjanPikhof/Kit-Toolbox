# Contributing to Kit's Toolkit

This guide is for AI agents and developers adding new functions to Kit's Toolkit.

## Quick Start for AI Agents

When asked to add a new function to the toolkit:

1. **Read the pattern** (`llm_prompts/kit_pattern.md`)
2. **Choose or create a category** (images, media, system, aliases, etc.)
3. **Use the template generator** to create the skeleton
4. **Implement the function**
5. **Validate the implementation**
6. **Test it works**

## Step-by-Step Guide

### Step 1: Determine the Category

Categories organize functions by purpose. Examples:
- **images**: Image processing (ImageMagick-based)
- **media**: Video/audio processing (ffmpeg, yt-dlp)
- **system**: System utilities (symlinks, editors, etc.)
- **aliases**: Navigation shortcuts (goto-*, etc.)
- **lsd**: File listing enhancements

**Decision Tree:**
- Does it process images? → Use `images.sh`
- Does it process media (video/audio)? → Use `media.sh`
- Is it a system utility? → Use `system.sh`
- Is it a navigation shortcut? → Use `aliases.sh`
- Does it enhance file listing? → Use `lsd.sh`
- Nothing fits? → Create a new category file

If creating a new category:
1. Create `functions/mycategory.sh` with proper headers
2. Add entry to `categories.conf`
3. Update `llm_prompts/kit_pattern.md` with new category

### Step 2: Generate Function Template

```bash
cd $KIT_EXT_DIR  # wherever you installed kit-toolkit
./scripts/new-function.sh <category> <function-name> <description>
```

Example:
```bash
./scripts/new-function.sh images resize-png "Resize PNG files to specific width"
```

This creates a template with:
- Help block structure
- Input validation skeleton
- Dependency checking framework
- Error handling template
- Success message

### Step 3: Implement the Function

Edit `functions/category.sh` and replace the placeholder with actual implementation.

**Essential checklist:**
- [ ] Help block shows usage, description, and examples
- [ ] All required arguments validated (exit code 2 if missing)
- [ ] All file existence checked (exit code 1 if not found)
- [ ] All dependencies checked before use (exit code 1 if missing)
- [ ] Error messages go to stderr (`echo "..." >&2`)
- [ ] Success returns exit code 0
- [ ] Success message explains what was created/modified

**Example function structure:**

```bash
my-function() {
    # Help block - ALWAYS FIRST
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit my-function <input_file> [output_file]
Description: Brief description of what function does
Example: kit my-function input.txt output.txt
EOF
        return 0
    fi

    # Input validation
    if [[ -z "$1" ]]; then
        echo "Error: Missing input file" >&2
        return 2
    fi

    if [[ ! -f "$1" ]]; then
        echo "Error: Input file '$1' does not exist" >&2
        return 1
    fi

    # Dependency check
    if ! command -v required_tool &> /dev/null; then
        echo "Error: required_tool not installed. Install with: brew install package" >&2
        return 1
    fi

    # Main logic
    local output="${2:-output.txt}"
    if ! required_tool "$1" > "$output"; then
        echo "Error: Failed to process file" >&2
        return 1
    fi

    # Success feedback
    echo "✅ Created: $output"
}
```

### Step 4: Update Function Header

Make sure the file header documents your new function:

```bash
# functions/category.sh
# Category: Category Name
# Description: What these functions do
# Dependencies: tool1, tool2
# Functions: existing-func1, existing-func2, your-new-func
```

### Step 5: Validate the Implementation

```bash
./scripts/validate-pattern.sh functions/category.sh
```

Checklist:
- [ ] Category header present
- [ ] Function listed in Functions header
- [ ] Help block shows -h and --help support
- [ ] Input validation present (missing args, file checks)
- [ ] Errors to stderr with &2
- [ ] Exit codes: 0 (success), 1 (error), 2 (invalid usage)
- [ ] Success message explains output

### Step 6: Manual Testing

```bash
# Load the functions
source loader.zsh

# Test help
kit my-function -h

# Test with missing arguments
kit my-function  # Should show error and return 2

# Test with invalid input
kit my-function nonexistent.txt  # Should show error and return 1

# Test with valid input
kit my-function valid.txt  # Should succeed
```

### Step 7: Update Completions (Automatic - No Action Needed)

**The completion system is FULLY DYNAMIC!** When you add a new function to a category file, tab completion works automatically after reloading your shell:

```bash
source ~/.zshrc
# or
exec zsh
```

The completion system automatically discovers:
- All functions from `functions/*.sh` (via `# Functions:` headers)
- All editor shortcuts from `editor.conf`
- All navigation shortcuts from `shortcuts.conf`

**For functions with custom completion options:**

If your function needs special tab completion (like `yt-download` completing `mp3|mp4`), edit the `_kit_get_custom_completion()` function in `completions/_kit`:

```zsh
_kit_get_custom_completion() {
    local cmd="$1"
    local pos="$2"

    case "$cmd" in
        your-new-function)
            if [[ $pos -eq 3 ]]; then
                _values 'options' 'option1' 'option2' 'option3'
                return 0
            fi
            ;;
    esac

    return 1
}
```

**To verify the completion system:**
```bash
./scripts/generate-completions.sh
```

## Pattern Requirements

Read `llm_prompts/kit_pattern.md` for complete details on:
- **Naming conventions**: lowercase-with-hyphens
- **Function template**: Required structure and sections
- **Error handling**: Exit codes and stderr messages
- **Input validation**: Required argument checking
- **Help documentation**: Usage, description, examples
- **Testing requirements**: Checklist for validation

## Common Patterns

### File Processing

```bash
function-name() {
    if [[ "$1" == "-h" || -z "$1" ]]; then
        cat << EOF
Usage: kit function-name <file>
Description: Process a file
Example: kit function-name myfile.txt
EOF
        return 0
    fi

    local input="$1"
    [[ -f "$input" ]] || { echo "Error: File not found" >&2; return 1; }

    # Process file
}
```

### Batch Processing

```bash
function-name() {
    if [[ "$1" == "-h" ]]; then
        cat << EOF
Usage: kit function-name <input_ext> <output_ext>
Example: kit function-name jpg png
EOF
        return 0
    fi

    local input_ext="$1"
    local output_ext="$2"

    for file in *."$input_ext"; do
        # Process each file
    done
}
```

### Directory Navigation

```bash
goto-project() {
    if [[ "$1" == "-h" ]]; then
        cat << EOF
Usage: kit goto-project
Description: Navigate to project directory
EOF
        return 0
    fi

    cd ~/path/to/project && ls
}
```

### Environment Setup

```bash
setup-env() {
    if [[ "$1" == "-h" ]]; then
        cat << EOF
Usage: kit setup-env <mode>
Description: Configure environment
Modes: on, off
EOF
        return 0
    fi

    case "$1" in
        on)
            export VARIABLE="value"
            echo "✅ Environment enabled"
            ;;
        off)
            unset VARIABLE
            echo "✅ Environment disabled"
            ;;
        *)
            echo "Error: Invalid mode" >&2
            return 2
            ;;
    esac
}
```

## Naming Conventions

- **Function names**: lowercase-with-hyphens (e.g., `resize-img`, `yt-download`)
- **Avoid verbs that are too generic**: Use `resize-img` not just `resize`
- **Avoid prefixes**: Use `resize-img` not `img-resize`
- **Group related functions**: `resize-img`, `upscale-img`, `optimize-img`

## Exit Codes

- **0**: Success - operation completed as expected
- **1**: Error - file not found, permission denied, operation failed
- **2**: Invalid usage - missing required arguments, invalid format

## Error Messages

Always send errors to stderr:
```bash
echo "Error: Description" >&2
return 1
```

Include:
- What went wrong
- Where (filename, value)
- How to fix it

Example:
```bash
echo "Error: Input file '$1' does not exist. Check path and try again." >&2
```

## Testing Your Function

```bash
# Verify help works
kit my-function -h

# Test invalid input
kit my-function          # Should return 2
kit my-function missing  # Should return 1

# Test valid input
kit my-function valid    # Should return 0 and show success message
```

## Questions?

Refer to:
- `llm_prompts/kit_pattern.md` - Complete pattern specification
- Existing functions in `functions/*.sh` - Real examples
- `SKILL.md` - Overview of the toolkit structure

---

**Remember:** Every function should be usable, discoverable, and maintainable. The patterns exist to ensure consistency across the entire toolkit.
