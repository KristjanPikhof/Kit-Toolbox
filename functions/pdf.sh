# pdf.sh - PDF processing utilities using qpdf
# Category: PDF Processing
# Description: Split, merge, compress, and rotate PDF files
# Dependencies: qpdf
# Functions: pdf-split, pdf-merge, pdf-compress, pdf-rotate

# Helper function to check qpdf and show install instructions
_kit_check_qpdf() {
    if ! command -v qpdf &> /dev/null; then
        echo "Error: qpdf not installed." >&2
        local install_cmd
        install_cmd=$(_kit_get_package_install_cmd "qpdf")
        if [[ "$install_cmd" != Error:* ]]; then
            echo "Install with: $install_cmd" >&2
        fi
        return 1
    fi
    return 0
}

pdf-split() {
    local force=false
    local input=""
    local pages=""
    local output=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit pdf-split <input.pdf> <pages> [-o output.pdf] [-f|--force]
Description: Extract pages from a PDF file
Page syntax:
  Single page: "5"
  Range: "2-20"
  Multiple pages: "1,5,19"
  Mixed: "1-5,10,15-20"
Options:
  -o, --output FILE    Output filename (default: input_pages_X.pdf)
  -f, --force          Overwrite output if it exists
Examples:
  kit pdf-split document.pdf "1-10"
  kit pdf-split document.pdf "1,3,5,7" -o odd_pages.pdf
  kit pdf-split book.pdf "50-100" --force
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -o|--output)
                output="$2"
                shift 2
                ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                elif [[ -z "$pages" ]]; then
                    pages="$1"
                fi
                shift
                ;;
        esac
    done

    # Input validation
    if [[ -z "$input" ]]; then
        echo "Error: Missing input PDF file" >&2
        return 2
    fi

    if [[ -z "$pages" ]]; then
        echo "Error: Missing page specification" >&2
        return 2
    fi

    # Validate pages syntax (numbers, commas, hyphens only)
    if [[ ! "$pages" =~ ^[0-9,\-]+$ ]]; then
        echo "Error: Invalid page specification. Use numbers, commas, and hyphens only." >&2
        return 2
    fi

    # Security: reject shell metacharacters in input
    if [[ "$input" =~ [\|\&\$\`\'\;\<\>] ]]; then
        echo "Error: Invalid characters in filename" >&2
        return 2
    fi

    # Security: reject shell metacharacters in output
    if [[ -n "$output" && "$output" =~ [\|\&\$\`\'\;\<\>] ]]; then
        echo "Error: Invalid characters in output filename" >&2
        return 2
    fi

    # Check for path traversal attempts
    if [[ "$input" == *"../"* ]] || [[ "$input" == *"/.."* ]]; then
        echo "Error: Path contains traversal sequences" >&2
        return 2
    fi

    # File check
    if [[ ! -f "$input" ]]; then
        echo "Error: File not found: $input" >&2
        return 1
    fi

    # Check file extension
    if [[ "${input##*.}" != "pdf" && "${input##*.}" != "PDF" ]]; then
        echo "Error: Input file must be a PDF" >&2
        return 2
    fi

    # Dependency check
    if ! _kit_check_qpdf; then
        return 1
    fi

    # Generate output filename if not specified
    if [[ -z "$output" ]]; then
        local basename="${input%.*}"
        local sanitized_pages="${pages//,/_}"
        sanitized_pages="${sanitized_pages//-/_}"
        output="${basename}_pages_${sanitized_pages}.pdf"
    fi

    # Check if output file exists
    if [[ -f "$output" ]]; then
        if [[ "$force" == true ]]; then
            echo "Warning: Overwriting existing file '$output'" >&2
            rm -f "$output"
        else
            echo "Error: Output file '$output' already exists. Use --force to overwrite." >&2
            return 1
        fi
    fi

    # Execute qpdf
    if ! qpdf "$input" --pages . "$pages" -- "$output"; then
        echo "Error: Failed to split PDF" >&2
        return 1
    fi

    echo "Created: $output"
}

pdf-merge() {
    local force=false
    local output="merged.pdf"
    local -a inputs=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit pdf-merge <file1.pdf> <file2.pdf> [...] [-o output.pdf] [-f|--force]
Description: Combine multiple PDF files into one
Options:
  -o, --output FILE    Output filename (default: merged.pdf)
  -f, --force          Overwrite output if it exists
Examples:
  kit pdf-merge part1.pdf part2.pdf part3.pdf
  kit pdf-merge *.pdf -o combined.pdf
  kit pdf-merge doc1.pdf doc2.pdf -o result.pdf --force
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -o|--output)
                output="$2"
                # Security: reject shell metacharacters in output
                if [[ "$output" =~ [\|\&\$\`\'\;\<\>] ]]; then
                    echo "Error: Invalid characters in output filename" >&2
                    return 2
                fi
                shift 2
                ;;
            *)
                # Security: reject shell metacharacters
                if [[ "$1" =~ [\|\&\$\`\'\;\<\>] ]]; then
                    echo "Error: Invalid characters in filename: $1" >&2
                    return 2
                fi
                # Check for path traversal
                if [[ "$1" == *"../"* ]] || [[ "$1" == *"/.."* ]]; then
                    echo "Error: Path contains traversal sequences" >&2
                    return 2
                fi
                inputs+=("$1")
                shift
                ;;
        esac
    done

    # Input validation
    if [[ ${#inputs[@]} -lt 2 ]]; then
        echo "Error: At least 2 PDF files required" >&2
        return 2
    fi

    # Validate all input files
    for file in "${inputs[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo "Error: File not found: $file" >&2
            return 1
        fi
        if [[ "${file##*.}" != "pdf" && "${file##*.}" != "PDF" ]]; then
            echo "Error: Not a PDF file: $file" >&2
            return 2
        fi
    done

    # Dependency check
    if ! _kit_check_qpdf; then
        return 1
    fi

    # Check if output file exists
    if [[ -f "$output" ]]; then
        if [[ "$force" == true ]]; then
            echo "Warning: Overwriting existing file '$output'" >&2
            rm -f "$output"
        else
            echo "Error: Output file '$output' already exists. Use --force to overwrite." >&2
            return 1
        fi
    fi

    # Execute qpdf
    if ! qpdf --empty --pages "${inputs[@]}" -- "$output"; then
        echo "Error: Failed to merge PDFs" >&2
        return 1
    fi

    echo "Merged ${#inputs[@]} files into: $output"
}

pdf-compress() {
    local force=false
    local input=""
    local output=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit pdf-compress <input.pdf> [-o output.pdf] [-f|--force]
Description: Reduce PDF file size using linearization and object streams
Options:
  -o, --output FILE    Output filename (default: input_compressed.pdf)
  -f, --force          Overwrite output if it exists
Examples:
  kit pdf-compress large_scan.pdf
  kit pdf-compress report.pdf -o report_small.pdf
  kit pdf-compress document.pdf --force
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -o|--output)
                output="$2"
                shift 2
                ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                fi
                shift
                ;;
        esac
    done

    # Input validation
    if [[ -z "$input" ]]; then
        echo "Error: Missing input PDF file" >&2
        return 2
    fi

    # Security: reject shell metacharacters
    if [[ "$input" =~ [\|\&\$\`\'\;\<\>] ]]; then
        echo "Error: Invalid characters in filename" >&2
        return 2
    fi

    # Security: reject shell metacharacters in output
    if [[ -n "$output" && "$output" =~ [\|\&\$\`\'\;\<\>] ]]; then
        echo "Error: Invalid characters in output filename" >&2
        return 2
    fi

    # Check for path traversal attempts
    if [[ "$input" == *"../"* ]] || [[ "$input" == *"/.."* ]]; then
        echo "Error: Path contains traversal sequences" >&2
        return 2
    fi

    # File check
    if [[ ! -f "$input" ]]; then
        echo "Error: File not found: $input" >&2
        return 1
    fi

    # Check file extension
    if [[ "${input##*.}" != "pdf" && "${input##*.}" != "PDF" ]]; then
        echo "Error: Input file must be a PDF" >&2
        return 2
    fi

    # Dependency check
    if ! _kit_check_qpdf; then
        return 1
    fi

    # Generate output filename if not specified
    if [[ -z "$output" ]]; then
        local basename="${input%.*}"
        output="${basename}_compressed.pdf"
    fi

    # Check if output file exists
    if [[ -f "$output" ]]; then
        if [[ "$force" == true ]]; then
            echo "Warning: Overwriting existing file '$output'" >&2
            rm -f "$output"
        else
            echo "Error: Output file '$output' already exists. Use --force to overwrite." >&2
            return 1
        fi
    fi

    # Get original file size
    local original_size
    original_size=$(du -h "$input" | cut -f1)

    # Execute qpdf with compression options
    if ! qpdf --linearize --object-streams=generate "$input" "$output"; then
        echo "Error: Failed to compress PDF" >&2
        return 1
    fi

    # Get compressed file size
    local compressed_size
    compressed_size=$(du -h "$output" | cut -f1)

    echo "Compressed: $output ($original_size → $compressed_size)"
}

pdf-rotate() {
    local force=false
    local input=""
    local degrees=""
    local pages=""
    local output=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit pdf-rotate <input.pdf> <degrees> [pages] [-o output.pdf] [-f|--force]
Description: Rotate PDF pages by specified degrees
Degrees: 90, 180, or 270 (clockwise)
Page syntax (optional, default: all pages):
  Single page: "5"
  Range: "2-20"
  Multiple pages: "1,5,19"
  Mixed: "1-5,10,15-20"
Options:
  -o, --output FILE    Output filename (default: input_rotated.pdf)
  -f, --force          Overwrite output if it exists
Examples:
  kit pdf-rotate scan.pdf 90                    # Rotate all pages
  kit pdf-rotate doc.pdf 180 "1,3"              # Rotate specific pages
  kit pdf-rotate book.pdf 270 "5-10" -o fixed.pdf
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -o|--output)
                output="$2"
                shift 2
                ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                elif [[ -z "$degrees" ]]; then
                    degrees="$1"
                elif [[ -z "$pages" ]]; then
                    pages="$1"
                fi
                shift
                ;;
        esac
    done

    # Input validation
    if [[ -z "$input" ]]; then
        echo "Error: Missing input PDF file" >&2
        return 2
    fi

    if [[ -z "$degrees" ]]; then
        echo "Error: Missing rotation degrees" >&2
        return 2
    fi

    # Validate degrees
    if [[ "$degrees" != "90" && "$degrees" != "180" && "$degrees" != "270" ]]; then
        echo "Error: Degrees must be 90, 180, or 270" >&2
        return 2
    fi

    # Validate pages syntax if provided (numbers, commas, hyphens only)
    if [[ -n "$pages" && ! "$pages" =~ ^[0-9,\-]+$ ]]; then
        echo "Error: Invalid page specification. Use numbers, commas, and hyphens only." >&2
        return 2
    fi

    # Security: reject shell metacharacters
    if [[ "$input" =~ [\|\&\$\`\'\;\<\>] ]]; then
        echo "Error: Invalid characters in filename" >&2
        return 2
    fi

    # Security: reject shell metacharacters in output
    if [[ -n "$output" && "$output" =~ [\|\&\$\`\'\;\<\>] ]]; then
        echo "Error: Invalid characters in output filename" >&2
        return 2
    fi

    # Check for path traversal attempts
    if [[ "$input" == *"../"* ]] || [[ "$input" == *"/.."* ]]; then
        echo "Error: Path contains traversal sequences" >&2
        return 2
    fi

    # File check
    if [[ ! -f "$input" ]]; then
        echo "Error: File not found: $input" >&2
        return 1
    fi

    # Check file extension
    if [[ "${input##*.}" != "pdf" && "${input##*.}" != "PDF" ]]; then
        echo "Error: Input file must be a PDF" >&2
        return 2
    fi

    # Dependency check
    if ! _kit_check_qpdf; then
        return 1
    fi

    # Generate output filename if not specified
    if [[ -z "$output" ]]; then
        local basename="${input%.*}"
        output="${basename}_rotated.pdf"
    fi

    # Check if output file exists
    if [[ -f "$output" ]]; then
        if [[ "$force" == true ]]; then
            echo "Warning: Overwriting existing file '$output'" >&2
            rm -f "$output"
        else
            echo "Error: Output file '$output' already exists. Use --force to overwrite." >&2
            return 1
        fi
    fi

    # Build rotation spec (default to all pages if not specified)
    local rotation_spec="+${degrees}"
    if [[ -n "$pages" ]]; then
        rotation_spec="+${degrees}:${pages}"
    fi

    # Execute qpdf
    if ! qpdf "$input" --rotate="$rotation_spec" -- "$output"; then
        echo "Error: Failed to rotate PDF" >&2
        return 1
    fi

    if [[ -n "$pages" ]]; then
        echo "Rotated pages $pages by ${degrees}°: $output"
    else
        echo "Rotated all pages by ${degrees}°: $output"
    fi
}
