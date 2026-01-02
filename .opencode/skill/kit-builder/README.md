# Kit Builder Skill

An intelligent skill for Claude Code that helps create production-ready shell functions for Kit's Toolkit following established patterns and best practices.

## Overview

Kit Builder guides you through creating new toolkit functions by:

1. **Asking intelligent questions** to understand requirements
2. **Determining the right category** for your function
3. **Generating pattern-compliant code** using templates
4. **Validating** against kit_pattern.md requirements
5. **Guiding comprehensive testing** to ensure quality
6. **Integrating with toolkit scripts** (new-function.sh, validate-pattern.sh, etc.)

## Documentation Structure

- **[SKILL.md](SKILL.md)** - Main skill documentation with complete workflow
- **[examples.md](examples.md)** - Concrete examples of function creation
- **[reference.md](reference.md)** - Quick reference for common patterns and troubleshooting

## Quick Start

### Creating a Simple Function

1. Tell Claude what you want:
   ```
   "I want to create a function that resizes images to 800px width"
   ```

2. Answer the questions Claude asks about:
   - Required/optional arguments
   - Dependencies needed
   - Error handling requirements

3. Claude will:
   - Generate the function using templates
   - Validate pattern compliance
   - Guide you through testing
   - Ensure everything works correctly

### Example Session

**You:** "Create a function to convert all PNG files in a directory to WebP format"

**Claude (via Kit Builder skill):**
- Asks: Batch processing? Quality level? Preserve originals?
- Determines: Goes in `images.sh` category
- Suggests: Function name `convert-png-to-webp-batch`
- Generates: Complete function with validation and error handling
- Validates: Runs pattern validator
- Tests: Guides through test cases

**Result:** A working, validated, tested function ready to use

## What Makes Kit Builder Better

Compared to the older kit-function-creator skill, Kit Builder is:

✅ **More Streamlined** - Focused workflow, less verbose
✅ **Better Integrated** - Works with all toolkit scripts
✅ **More Practical** - Action-oriented with concrete examples
✅ **Better Testing** - Comprehensive test guidance
✅ **Better Patterns** - Aligned with latest kit_pattern.md
✅ **Progressive Disclosure** - Reference docs for advanced usage

## Features

### Intelligent Questioning
Asks only relevant questions based on function type:
- Image functions → formats, quality, batch processing
- System utilities → permissions, safety, rollback
- Media functions → codecs, quality, streaming vs. file

### Pattern Validation
Ensures every function includes:
- Help block with `-h` and `--help` support
- Input validation with proper exit codes
- Dependency checking
- Error messages to stderr
- Success confirmations
- Comprehensive examples

### Category Management
- Helps choose existing categories
- Guides creating new categories when needed
- Updates category headers automatically
- Maintains categories.conf

### Testing Guidance
Provides specific test cases:
- Help display tests
- Invalid input tests
- File not found tests
- Success scenario tests
- Edge case tests

## Usage in Claude Code

The skill activates automatically when you mention:
- "create function"
- "add function"
- "new kit function"
- "add to toolkit"
- "create utility"
- References to kit_pattern.md

Or invoke it explicitly:
```
Use the kit-builder skill to create...
```

## Integration with Toolkit Scripts

Kit Builder leverages all toolkit development scripts:

### new-function.sh
Generates function templates with:
- Proper header structure
- Help block skeleton
- Input validation template
- Error handling framework

### validate-pattern.sh
Validates functions against kit_pattern.md:
- Category header present
- Function listed in header
- Help block included
- Input validation present
- Error codes correct

### generate-completions.sh
Verifies the dynamic completion system:
- The completion system is fully dynamic (auto-discovers functions)
- No manual regeneration needed
- Use this script to verify the system is working correctly

### validate-shortcuts.sh
Validates shortcuts configuration:
- No duplicate names
- Valid paths
- No function conflicts

## Common Use Cases

### 1. Simple File Conversion
Create functions that convert files from one format to another
- Example: PNG to JPEG, MP4 to WebM, etc.

### 2. Batch Processing
Process multiple files matching a pattern
- Example: Optimize all images in a directory

### 3. System Utilities
Create helper functions for common tasks
- Example: Create backups, manage symlinks, etc.

### 4. Media Processing
Download, convert, or manipulate media files
- Example: YouTube downloads, audio extraction

### 5. Development Tools
Create utilities for development workflows
- Example: Minify CSS/JS, lint code, run tests

## Documentation

### Main Documentation (SKILL.md)
Complete workflow covering:
- When to use the skill
- Phase-by-phase creation process
- Pattern requirements
- Category management
- Testing procedures
- Quality checklist

### Examples (examples.md)
Real-world examples including:
- Simple file conversion function
- Batch processing function
- System utility with options
- Creating new categories
- Complex error handling
- Testing patterns

### Quick Reference (reference.md)
Fast lookup for:
- Workflow commands
- Pattern templates
- Validation patterns
- Error handling patterns
- Exit code standards
- Testing checklist
- Common issues and solutions
- Dependency detection
- File output patterns

## Requirements

- Kit's Toolkit installed (`$KIT_EXT_DIR` set)
- Access to toolkit scripts in `scripts/` directory
- Write access to `functions/` directory
- Shell environment (zsh or bash)

## Best Practices

1. **Be specific** - "Resize images" not "Image stuff"
2. **Explain context** - "For web optimization" helps
3. **Mention constraints** - "Must work offline" or "Needs to be fast"
4. **Show examples** - How you'd use it: `kit my-func file.txt`
5. **Test thoroughly** - Follow all test scenarios

## Quality Standards

Every function created with Kit Builder:
- ✅ Follows naming conventions (lowercase-with-hyphens)
- ✅ Has complete help documentation
- ✅ Validates all inputs
- ✅ Handles errors gracefully
- ✅ Uses correct exit codes (0, 1, 2)
- ✅ Checks dependencies
- ✅ Provides success confirmation
- ✅ Passes pattern validation
- ✅ Works with edge cases (spaces, special chars, etc.)

## Troubleshooting

See [reference.md](reference.md) for detailed troubleshooting, including:
- Function not found after creation
- Pattern validation failures
- Help block not displaying
- Errors not visible
- Tab completion not working

## Version

Kit Builder v1.0 - Created for Kit's Toolkit v2.0

## License

Part of Kit's Toolkit - Same license as parent project

---

**Ready to build?** Start by telling Claude what function you want to create, and Kit Builder will guide you through the entire process!
