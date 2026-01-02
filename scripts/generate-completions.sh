#!/bin/bash
# generate-completions.sh - Auto-generate zsh completions from function files
#
# This script scans all function files in the functions/ directory and
# generates an updated _kit completion script.

set -e

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXT_DIR="$(dirname "$SCRIPT_DIR")"
FUNCTIONS_DIR="$EXT_DIR/functions"
COMPLETIONS_DIR="$EXT_DIR/completions"
OUTPUT_FILE="$COMPLETIONS_DIR/_kit"

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat << 'EOF'
Usage: generate-completions.sh [output-file]
Description: Auto-generate zsh completion script from function definitions
Output: Writes to kit-toolkit/completions/_kit (or specified file)
Example:
  ./scripts/generate-completions.sh
  ./scripts/generate-completions.sh custom-completion.sh
EOF
    exit 0
fi

if [[ -n "$1" ]]; then
    OUTPUT_FILE="$1"
fi

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Function to extract help description from function
get_function_description() {
    local func_name="$1"
    local func_file="$2"

    # Find the function in the file and extract description from Usage or Description line
    awk -v fname="$func_name" -v found=0 '
        /^'$func_name'\(\)/ {found=1; next}
        found && /Usage:/ {
            gsub(/.*Usage: kit [^ ]* */, "")
            gsub(/ *Example.*/, "")
            print substr($0, 1, 50)
            exit
        }
        found && /Description:/ {
            gsub(/.*Description: /, "")
            print substr($0, 1, 50)
            exit
        }
    ' "$func_file"
}

# Generate the completion script
cat > "$OUTPUT_FILE" << 'COMPLETION_HEADER'
#compdef kit
# Completion script for kit command (auto-generated)
# Provides tab-completion for function names and arguments

local -a commands
local expl

# Get all available functions from function files
_kit_get_commands() {
    local functions_dir="$KIT_EXT_DIR/functions"

    for file in "$functions_dir"/*.sh; do
        if [[ -f "$file" ]]; then
            local functions=$(grep "^# Functions:" "$file" | cut -d: -f2- | xargs | tr ',' ' ')
            for func in $functions; do
                echo "$func"
            done
        fi
    done | sort -u
}

# Build command list with descriptions
_kit_build_command_list() {
    local functions_dir="$KIT_EXT_DIR/functions"
    local -a commands_with_desc=()

    for file in "$functions_dir"/*.sh; do
        if [[ -f "$file" ]]; then
            local functions=$(grep "^# Functions:" "$file" | cut -d: -f2- | xargs | tr ',' ' ')
            local category=$(grep "^# Category:" "$file" | cut -d: -f2- | xargs)

            for func in $functions; do
                # Try to get short description from function help
                local desc=$(declare -f "$func" 2>/dev/null | grep -o 'Usage:.*$' | head -1 | sed 's/Usage: kit [^ ]* *//' | sed 's/ *Example.*//' | cut -c1-50)
                if [[ -z "$desc" ]]; then
                    desc="$category"
                fi
                commands_with_desc+=("$func:$desc")
            done
        fi
    done

    printf '%s\n' "$commands_with_desc[@]"
}

# Main completion logic
case "$CURRENT" in
    2)
        # Complete the command name (first argument after 'kit')
        local -a commands_list=()
        while IFS=: read -r cmd desc; do
            commands_list+=("$cmd:$desc")
        done < <(_kit_build_command_list)

        _describe 'kit commands' commands_list

        # Also add special commands
        local -a special_commands=(
            '-h:Show help'
            '--help:Show help'
            '--search:Search functions by keyword'
            '--list-categories:List all categories'
        )
        _describe 'special commands' special_commands
        ;;
COMPLETION_HEADER

# Build the case statement for individual commands
echo "    *)" >> "$OUTPUT_FILE"
echo "        # Complete arguments based on the command" >> "$OUTPUT_FILE"
echo "        local cmd=\"\${words[2]}\"" >> "$OUTPUT_FILE"
echo "        case \"\$cmd\" in" >> "$OUTPUT_FILE"

# Extract all functions and add them to the case statement
for file in "$FUNCTIONS_DIR"/*.sh; do
    if [[ -f "$file" ]]; then
        while IFS=, read -r func; do
            func=$(echo "$func" | xargs)  # Trim whitespace
            if [[ -n "$func" ]]; then
                # Get description
                desc=$(get_function_description "$func" "$file")

                # Determine what kind of arguments this function takes
                case "$func" in
                    resize-img|upscale-img|optimize-img|convert-heic|removeaudio|convert-to-mp3)
                        echo "            $func)" >> "$OUTPUT_FILE"
                        echo "                _files" >> "$OUTPUT_FILE"
                        echo "                ;;" >> "$OUTPUT_FILE"
                        ;;
                    yt-download)
                        echo "            $func)" >> "$OUTPUT_FILE"
                        echo "                if [[ \$CURRENT -eq 3 ]]; then" >> "$OUTPUT_FILE"
                        echo "                    _values 'mode' 'mp3' 'mp4'" >> "$OUTPUT_FILE"
                        echo "                elif [[ \$CURRENT -eq 4 ]]; then" >> "$OUTPUT_FILE"
                        echo "                    _message 'URL'" >> "$OUTPUT_FILE"
                        echo "                fi" >> "$OUTPUT_FILE"
                        echo "                ;;" >> "$OUTPUT_FILE"
                        ;;
                    *)
                        echo "            $func)" >> "$OUTPUT_FILE"
                        echo "                _files" >> "$OUTPUT_FILE"
                        echo "                ;;" >> "$OUTPUT_FILE"
                        ;;
                esac
            fi
        done < <(grep "^# Functions:" "$file" | cut -d: -f2- | tr ',' '\n')
    fi
done

# Close the case statement
cat >> "$OUTPUT_FILE" << 'COMPLETION_FOOTER'
            *)
                _files
                ;;
        esac
        ;;
esac
COMPLETION_FOOTER

echo "✅ Generated completion script: $OUTPUT_FILE"
echo "   Functions found: $(grep -h "^# Functions:" "$FUNCTIONS_DIR"/*.sh | sed 's/.*: //' | tr ',' '\n' | wc -l)"
