#!/bin/bash
# new-function.sh - Generate a new function template following kit_pattern.md
#
# Creates a function template that follows all the patterns and best practices
# for Kit's Toolkit functions

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_DIR="$(dirname "$SCRIPT_DIR")"

if [[ "$1" == "-h" || "$1" == "--help" || $# -lt 3 ]]; then
    cat << 'EOF'
Usage: new-function.sh <category> <function-name> <description>
Description: Generate a new function template following kit_pattern.md
Arguments:
  <category>       The category file (without .sh) - e.g., "images", "system"
  <function-name>  Name of the new function (lowercase-with-hyphens)
  <description>    Brief description of what the function does

Examples:
  ./scripts/new-function.sh images resize-png "Resize PNG files to target width"
  ./scripts/new-function.sh system check-disk "Check disk space usage"
  ./scripts/new-function.sh media extract-audio "Extract audio from video file"

The function template will be generated and added to the appropriate
functions/category.sh file. The function follows all patterns from kit_pattern.md
and includes:
  - Help block with -h flag support
  - Input validation
  - Dependency checking
  - Error handling with proper exit codes
  - Success feedback
EOF
    exit 0
fi

CATEGORY="$1"
FUNC_NAME="$2"
DESCRIPTION="$3"
FUNC_FILE="$EXT_DIR/functions/${CATEGORY}.sh"

# Validate arguments
if [[ ! "$FUNC_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
    echo "Error: Function name must be lowercase with hyphens (e.g., my-function)" >&2
    exit 1
fi

if [[ ! -f "$FUNC_FILE" ]]; then
    echo "Error: Category file not found: $FUNC_FILE" >&2
    echo "Available categories:" >&2
    ls "$EXT_DIR/functions"/*.sh 2>/dev/null | xargs basename -a | sed 's/\.sh$//' | sed 's/^/  /' >&2
    exit 1
fi

# Check if function already exists
if grep -q "^${FUNC_NAME}()" "$FUNC_FILE"; then
    echo "Error: Function '$FUNC_NAME' already exists in $FUNC_FILE" >&2
    exit 1
fi

# Generate function template
TEMPLATE="
# ${FUNC_NAME} - ${DESCRIPTION}
${FUNC_NAME}() {
    if [[ \"\$1\" == \"-h\" || \"\$1\" == \"--help\" || -z \"\$1\" ]]; then
        cat << 'HELP'
Usage: kit ${FUNC_NAME} <required_arg>
Description: ${DESCRIPTION}
Example: kit ${FUNC_NAME} myfile
HELP
        return 0
    fi

    # Input validation
    if [[ -z \"\$1\" ]]; then
        echo \"Error: Missing required argument\" >&2
        return 2
    fi

    # Dependency check (customize as needed)
    # if ! command -v required_tool &> /dev/null; then
    #     echo \"Error: required_tool not installed. Install with: brew install package\" >&2
    #     return 1
    # fi

    # Main logic
    echo \"Placeholder: Implement the function logic\"

    # Success feedback
    echo \"✅ ${FUNC_NAME} completed successfully\"
}
"

# Update the Functions list in the file header
CURRENT_FUNCTIONS=$(grep "^# Functions:" "$FUNC_FILE" | cut -d: -f2-)
NEW_FUNCTIONS="$CURRENT_FUNCTIONS, $FUNC_NAME"

# Create temporary file with updated header
TEMP_FILE=$(mktemp) || { echo "Error: Cannot create temp file" >&2; exit 1; }
trap "rm -f \"$TEMP_FILE\"" EXIT

# Copy file up to the first function definition
awk "
/^# Functions:/ {
    print \"# Functions:${NEW_FUNCTIONS}\"
    next
}
{ print }
" "$FUNC_FILE" > "$TEMP_FILE"

# Append the new function
echo "$TEMPLATE" >> "$TEMP_FILE"

# Replace original file
mv "$TEMP_FILE" "$FUNC_FILE"

echo "✅ Created function template: $FUNC_NAME"
echo "📝 Edit: $FUNC_FILE"
echo ""
echo "Next steps:"
echo "  1. Edit the function in $FUNC_FILE"
echo "  2. Replace placeholder implementation with actual code"
echo "  3. Update input validation, dependencies, and error handling"
echo "  4. Run: ./scripts/validate-pattern.sh functions/${CATEGORY}.sh"
echo "  5. Test: kit $FUNC_NAME -h"
