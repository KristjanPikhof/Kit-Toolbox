# pdf.sh - PDF processing utilities using qpdf
# Category: PDF Processing
# Description: Split, merge, compress, and rotate PDF files
# Dependencies: qpdf
# Functions: pdf-split, pdf-merge, pdf-compress, pdf-rotate, pdf-burst

# Alias for backward compatibility — delegates to the unified helper in deps.sh
_kit_check_qpdf() { _kit_require qpdf; }

pdf-split() {
    local force=false
    local pages=""
    local output=""
    local output_dir=""
    local recursive=false
    local pages_option=false
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit pdf-split --pages <pages> <path>... [options]
Description: Extract the same page selection from one or more PDF files
Page syntax:
  Single page: "5"
  Range: "2-20"
  Multiple pages: "1,5,19"
  Mixed: "1-5,10,15-20"
Default output:
  One file                 Creates a sibling result
  A folder                 Creates <folder>/split-pdf/ for its results
Optional controls:
  -p, --pages PAGES      Pages to extract
  -o, --output FILE      Output filename, valid with one input only
  -d, --output-dir DIR   Use a custom result folder
  -r, --recursive        Also include matching files in subfolders
  -f, --force            Overwrite existing outputs
Examples:
  kit pdf-split --pages "1-10" document.pdf
  kit pdf-split --pages "1,3,5" report.pdf invoice.pdf
  kit pdf-split --pages "1-5" ./documents --recursive
Legacy: kit pdf-split document.pdf "1-10"
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -p|--pages)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a page specification" >&2
                    return 2
                fi
                pages="$2"
                pages_option=true
                shift 2
                ;;
            -o|--output)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires an output file" >&2
                    return 2
                fi
                output="$2"
                shift 2
                ;;
            -d|--output-dir)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a directory" >&2
                    return 2
                fi
                output_dir="$2"
                shift 2
                ;;
            -r|--recursive)
                recursive=true
                shift
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                return 2
                ;;
            *)
                positional+=("$1")
                shift
                ;;
        esac
    done

    local -a targets=()
    if [[ "$pages_option" == true ]]; then
        targets=("${positional[@]}")
    else
        if [[ ${#positional[@]} -ne 2 ]]; then
            echo "Error: Multiple inputs require --pages <pages>" >&2
            return 2
        fi
        targets=("${positional[1]}")
        pages="${positional[2]}"
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

    if [[ -n "$output" && -n "$output_dir" ]]; then
        echo "Error: Use either --output or --output-dir, not both" >&2
        return 2
    fi

    _kit_collect_files _kit_is_pdf_file "$recursive" PDF "${targets[@]}" || return $?
    _kit_exclude_collected_subdir "split-pdf"
    local -a inputs=("${reply[@]}")
    if [[ -n "$output" && ${#inputs[@]} -ne 1 ]]; then
        echo "Error: --output requires exactly one input. Use --output-dir for batches." >&2
        return 2
    fi

    # Dependency check
    if ! _kit_check_qpdf; then
        return 1
    fi

    _kit_prepare_output_dir "$output_dir" || return 1
    local sanitized_pages="${pages//,/_}"
    sanitized_pages="${sanitized_pages//-/_}"
    local input current_output index
    local -a outputs=()
    local -A seen_outputs=()
    for ((index=1; index<=${#inputs[@]}; index++)); do
        input="${inputs[$index]}"
        if [[ -n "$output" ]]; then
            current_output="$output"
        elif [[ -n "$output_dir" ]]; then
            current_output="$output_dir/${input:t:r}_pages_${sanitized_pages}.pdf"
        else
            _kit_default_output_for_collected "$input" split-pdf "_pages_${sanitized_pages}" pdf || return 1
            current_output="$REPLY"
        fi
        _kit_prepare_output_dir "${current_output:h}" || return 1
        if [[ -n "${seen_outputs[${current_output:A}]:-}" ]]; then
            echo "Error: Multiple inputs would create '$current_output'" >&2
            return 1
        fi
        seen_outputs[${current_output:A}]=1
        if [[ -e "$current_output" && "$force" != true ]]; then
            echo "Error: Output file '$current_output' already exists. Use --force to overwrite." >&2
            return 1
        fi
        outputs+=("$current_output")
    done

    local success=0
    local failed=0
    for ((index=1; index<=${#inputs[@]}; index++)); do
        input="${inputs[$index]}"
        current_output="${outputs[$index]}"
        if qpdf "$input" --pages . "$pages" -- "$current_output"; then
            echo "Created: $current_output"
            ((success++))
        else
            echo "Error: Failed to split '$input'" >&2
            ((failed++))
        fi
    done
    echo "Processed $success file(s); $failed failed"
    [[ $failed -eq 0 ]]
}

pdf-merge() {
    local force=false
    local output="merged.pdf"
    local recursive=false
    local -a targets=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit pdf-merge <path>... [options]
Description: Combine two or more PDF files into one
Options:
  -o, --output FILE    Output filename (default: merged.pdf)
  -r, --recursive      Also include matching files in subfolders
  -f, --force          Overwrite output if it exists
Examples:
  kit pdf-merge part1.pdf part2.pdf part3.pdf
  kit pdf-merge *.pdf -o combined.pdf
  kit pdf-merge ./chapters -o book.pdf
  kit pdf-merge ./documents --recursive -o archive.pdf
  kit pdf-merge doc1.pdf doc2.pdf -o result.pdf --force
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -r|--recursive)
                recursive=true
                shift
                ;;
            -o|--output)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires an output file" >&2
                    return 2
                fi
                output="$2"
                shift 2
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                return 2
                ;;
            *)
                targets+=("$1")
                shift
                ;;
        esac
    done

    _kit_collect_files _kit_is_pdf_file "$recursive" PDF "${targets[@]}" || return $?
    local -a inputs=("${reply[@]}")
    if [[ ${#inputs[@]} -lt 2 ]]; then
        echo "Error: At least 2 PDF files required" >&2
        return 2
    fi

    local file
    for file in "${inputs[@]}"; do
        if [[ "${file:A}" == "${output:A}" ]]; then
            echo "Error: Output file cannot also be an input: $output" >&2
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
    if ! qpdf --warning-exit-0 --empty --pages "${inputs[@]}" -- "$output"; then
        echo "Error: Failed to merge PDFs" >&2
        return 1
    fi

    echo "Merged ${#inputs[@]} files into: $output"
}

pdf-compress() {
    local force=false
    local output=""
    local output_dir=""
    local recursive=false
    local -a targets=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit pdf-compress <path>... [options]
Description: Compress one or more PDF files using linearization and object streams
Default output:
  One file                 Creates a sibling such as report_compressed.pdf
  A folder                 Creates <folder>/compressed-pdf/ for its results
Optional controls:
  -o, --output FILE      Output filename, valid with one input only
  -d, --output-dir DIR   Use a custom result folder
  -r, --recursive        Also include matching files in subfolders
  -f, --force            Overwrite existing outputs
Examples:
  kit pdf-compress large_scan.pdf
  kit pdf-compress report.pdf invoice.pdf
  kit pdf-compress documents
  kit pdf-compress documents --recursive
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
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires an output file" >&2
                    return 2
                fi
                output="$2"
                shift 2
                ;;
            -d|--output-dir)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a directory" >&2
                    return 2
                fi
                output_dir="$2"
                shift 2
                ;;
            -r|--recursive)
                recursive=true
                shift
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                return 2
                ;;
            *)
                targets+=("$1")
                shift
                ;;
        esac
    done

    if [[ -n "$output" && -n "$output_dir" ]]; then
        echo "Error: Use either --output or --output-dir, not both" >&2
        return 2
    fi

    _kit_collect_files _kit_is_pdf_file "$recursive" PDF "${targets[@]}" || return $?
    _kit_exclude_collected_subdir "compressed-pdf"
    local -a inputs=("${reply[@]}")
    if [[ -n "$output" && ${#inputs[@]} -ne 1 ]]; then
        echo "Error: --output requires exactly one input. Use --output-dir for batches." >&2
        return 2
    fi

    # Dependency check
    if ! _kit_check_qpdf; then
        return 1
    fi

    _kit_prepare_output_dir "$output_dir" || return 1
    local input current_output index
    local -a outputs=()
    local -A seen_outputs=()
    for ((index=1; index<=${#inputs[@]}; index++)); do
        input="${inputs[$index]}"
        if [[ -n "$output" ]]; then
            current_output="$output"
        elif [[ -n "$output_dir" ]]; then
            current_output="$output_dir/${input:t:r}_compressed.pdf"
        else
            _kit_default_output_for_collected "$input" compressed-pdf _compressed pdf || return 1
            current_output="$REPLY"
        fi
        _kit_prepare_output_dir "${current_output:h}" || return 1
        if [[ -n "${seen_outputs[${current_output:A}]:-}" ]]; then
            echo "Error: Multiple inputs would create '$current_output'" >&2
            return 1
        fi
        seen_outputs[${current_output:A}]=1
        if [[ -e "$current_output" && "$force" != true ]]; then
            echo "Error: Output file '$current_output' already exists. Use --force to overwrite." >&2
            return 1
        fi
        outputs+=("$current_output")
    done

    local success=0
    local failed=0
    local original_size compressed_size
    for ((index=1; index<=${#inputs[@]}; index++)); do
        input="${inputs[$index]}"
        current_output="${outputs[$index]}"
        original_size=$(du -h "$input" | cut -f1)
        if qpdf --linearize --object-streams=generate "$input" "$current_output"; then
            compressed_size=$(du -h "$current_output" | cut -f1)
            echo "Compressed: $current_output ($original_size -> $compressed_size)"
            ((success++))
        else
            echo "Error: Failed to compress '$input'" >&2
            ((failed++))
        fi
    done
    echo "Processed $success file(s); $failed failed"
    [[ $failed -eq 0 ]]
}

pdf-rotate() {
    local force=false
    local degrees=""
    local pages=""
    local output=""
    local output_dir=""
    local recursive=false
    local degrees_option=false
    local -a positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit pdf-rotate --degrees <degrees> <path>... [options]
Description: Rotate pages in one or more PDF files
Degrees: 90, 180, or 270 (clockwise)
Page syntax (optional, default: all pages):
  Single page: "5"
  Range: "2-20"
  Multiple pages: "1,5,19"
  Mixed: "1-5,10,15-20"
Default output:
  One file                 Creates a sibling such as scan_rotated.pdf
  A folder                 Creates <folder>/rotated-pdf/ for its results
Optional controls:
  -a, --degrees NUM      Rotation: 90, 180, or 270
  -p, --pages PAGES      Pages to rotate (default: all)
  -o, --output FILE      Output filename, valid with one input only
  -d, --output-dir DIR   Use a custom result folder
  -r, --recursive        Also include matching files in subfolders
  -f, --force            Overwrite existing outputs
Examples:
  kit pdf-rotate --degrees 90 scan.pdf
  kit pdf-rotate --degrees 180 --pages "1,3" a.pdf b.pdf
  kit pdf-rotate --degrees 270 ./documents --recursive
Legacy: kit pdf-rotate scan.pdf 90 [pages]
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -a|--degrees)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires rotation degrees" >&2
                    return 2
                fi
                degrees="$2"
                degrees_option=true
                shift 2
                ;;
            -p|--pages)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a page specification" >&2
                    return 2
                fi
                pages="$2"
                shift 2
                ;;
            -o|--output)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires an output file" >&2
                    return 2
                fi
                output="$2"
                shift 2
                ;;
            -d|--output-dir)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a directory" >&2
                    return 2
                fi
                output_dir="$2"
                shift 2
                ;;
            -r|--recursive)
                recursive=true
                shift
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                return 2
                ;;
            *)
                positional+=("$1")
                shift
                ;;
        esac
    done

    local -a targets=()
    if [[ "$degrees_option" == true ]]; then
        targets=("${positional[@]}")
    else
        if [[ ${#positional[@]} -lt 2 || ${#positional[@]} -gt 3 ]]; then
            echo "Error: Multiple inputs require --degrees <degrees>" >&2
            return 2
        fi
        targets=("${positional[1]}")
        degrees="${positional[2]}"
        [[ ${#positional[@]} -eq 3 ]] && pages="${positional[3]}"
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

    if [[ -n "$output" && -n "$output_dir" ]]; then
        echo "Error: Use either --output or --output-dir, not both" >&2
        return 2
    fi

    _kit_collect_files _kit_is_pdf_file "$recursive" PDF "${targets[@]}" || return $?
    _kit_exclude_collected_subdir "rotated-pdf"
    local -a inputs=("${reply[@]}")
    if [[ -n "$output" && ${#inputs[@]} -ne 1 ]]; then
        echo "Error: --output requires exactly one input. Use --output-dir for batches." >&2
        return 2
    fi

    # Dependency check
    if ! _kit_check_qpdf; then
        return 1
    fi

    local rotation_spec="+${degrees}"
    if [[ -n "$pages" ]]; then
        rotation_spec="+${degrees}:${pages}"
    fi

    _kit_prepare_output_dir "$output_dir" || return 1
    local input current_output index
    local -a outputs=()
    local -A seen_outputs=()
    for ((index=1; index<=${#inputs[@]}; index++)); do
        input="${inputs[$index]}"
        if [[ -n "$output" ]]; then
            current_output="$output"
        elif [[ -n "$output_dir" ]]; then
            current_output="$output_dir/${input:t:r}_rotated.pdf"
        else
            _kit_default_output_for_collected "$input" rotated-pdf _rotated pdf || return 1
            current_output="$REPLY"
        fi
        _kit_prepare_output_dir "${current_output:h}" || return 1
        if [[ -n "${seen_outputs[${current_output:A}]:-}" ]]; then
            echo "Error: Multiple inputs would create '$current_output'" >&2
            return 1
        fi
        seen_outputs[${current_output:A}]=1
        if [[ -e "$current_output" && "$force" != true ]]; then
            echo "Error: Output file '$current_output' already exists. Use --force to overwrite." >&2
            return 1
        fi
        outputs+=("$current_output")
    done

    local success=0
    local failed=0
    for ((index=1; index<=${#inputs[@]}; index++)); do
        input="${inputs[$index]}"
        current_output="${outputs[$index]}"
        if qpdf "$input" --rotate="$rotation_spec" -- "$current_output"; then
            echo "Rotated: $current_output"
            ((success++))
        else
            echo "Error: Failed to rotate '$input'" >&2
            ((failed++))
        fi
    done
    echo "Processed $success file(s); $failed failed"
    [[ $failed -eq 0 ]]
}

_kit_pdf_burst_one() {
    local force=false
    local input=""
    local chunk_size=1
    local output_pattern=""
    local output_dir=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit pdf-burst <input.pdf> [pages_per_file] [-o pattern] [-d directory] [-f|--force]
Description: Split PDF into multiple files of fixed page count
Arguments:
  pages_per_file       Number of pages per output file (default: 1)
Options:
  -o, --output PATTERN Filename pattern (default: page_%d.pdf)
                       %d is replaced by the starting page number
  -d, --dir DIR        Output directory (default: input_filename_burst/)
  -f, --force          Overwrite output files if they exist
Examples:
  kit pdf-burst doc.pdf                 # Split into doc_burst/page_1.pdf...
  kit pdf-burst doc.pdf 2 -d .          # Split into current directory
  kit pdf-burst doc.pdf -o "part_%d.pdf" -d split_files/
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -o|--output)
                output_pattern="$2"
                shift 2
                ;;
            -d|--dir)
                output_dir="$2"
                shift 2
                ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                elif [[ "$1" =~ ^[0-9]+$ ]]; then
                    # Assume second arg is chunk size if it's a number
                    chunk_size="$1"
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

    # Validate chunk size
    if [[ ! "$chunk_size" =~ ^[0-9]+$ ]] || [[ "$chunk_size" -lt 1 ]]; then
        echo "Error: Pages per file must be a positive integer" >&2
        return 2
    fi

    # Security: reject shell metacharacters in input
    if [[ "$input" =~ [\|\&\$\`\'\;\<\>] ]]; then
        echo "Error: Invalid characters in filename" >&2
        return 2
    fi

    # Security: reject shell metacharacters in output pattern
    if [[ -n "$output_pattern" && "$output_pattern" =~ [\|\&\$\`\'\;\<\>] ]]; then
        echo "Error: Invalid characters in output pattern" >&2
        return 2
    fi

    # Security: reject shell metacharacters in output directory
    if [[ -n "$output_dir" && "$output_dir" =~ [\|\&\$\`\'\;\<\>] ]]; then
        echo "Error: Invalid characters in output directory" >&2
        return 2
    fi

    # Check for path traversal attempts in input
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

    # Determine output directory
    if [[ -z "$output_dir" ]]; then
        local input_basename="${input%.*}"
        output_dir="${input_basename}_burst"
    fi

    # Create output directory if it doesn't exist
    if [[ ! -d "$output_dir" ]]; then
        mkdir -p "$output_dir" || { echo "Error: Failed to create output directory '$output_dir'" >&2; return 1; }
        echo "Created directory: $output_dir"
    fi

    # Determine full output pattern
    if [[ -z "$output_pattern" ]]; then
        # Default filename pattern inside directory
        output_pattern="page_%d.pdf"
    fi

    # Ensure pattern contains %d
    if [[ "$output_pattern" != *"%d"* ]]; then
        echo "Warning: Output pattern missing '%d' placeholder. Appending '_%d.pdf'" >&2
        output_pattern="${output_pattern%.*}_%d.pdf"
    fi

    # Combine directory and pattern
    # If pattern is absolute path, use as is (unlikely). If relative, prepend dir.
    # Simple check for starting with /
    if [[ "$output_pattern" != /* ]]; then
        local full_path="$output_dir/$output_pattern"
    else
        local full_path="$output_pattern"
    fi

    # Pre-flight check: Verify we won't overwrite files (unless forced)
    if [[ "$force" != true ]]; then
        local page_count
        # Run qpdf without suppressing stderr to see potential errors (password, corruption, etc.)
        # Use --warning-exit-0 to allow success even with warnings (exit code 3 -> 0)
        if ! page_count=$(qpdf --warning-exit-0 --show-npages "$input"); then
            echo "Error: Failed to determine page count. qpdf output above." >&2
            return 1
        fi

        local i
        for ((i=1; i<=page_count; i+=chunk_size)); do
            local check_file
            # printf handles %d substitution
            printf -v check_file "$full_path" "$i"
            
            if [[ -f "$check_file" ]]; then
                echo "Error: Output file '$check_file' already exists. Use --force to overwrite." >&2
                return 1
            fi
        done
    fi

    # Execute qpdf
    # Use --warning-exit-0 to allow success even with warnings
    if ! qpdf --warning-exit-0 "$input" --split-pages="$chunk_size" "$full_path"; then
        echo "Error: Failed to burst PDF" >&2
        return 1
    fi

    echo "Successfully split '$input' into chunks of $chunk_size pages in '$output_dir'"
}

pdf-burst() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit pdf-burst <path>... [options]
Description: Split one or more PDFs into files with a fixed page count
Default output:
  One file                     Creates a sibling folder such as document_burst/
  A folder                     Creates <folder>/burst-pdf/ for its results
Optional controls:
  -p, --pages-per-file NUM  Pages per output file (default: 1)
  -o, --output PATTERN      Filename pattern (default: page_%d.pdf)
  -d, --output-dir DIR      Use a custom result folder
  -r, --recursive           Also include matching files in subfolders
  -f, --force               Overwrite existing outputs
Examples:
  kit pdf-burst document.pdf
  kit pdf-burst report.pdf invoice.pdf --pages-per-file 2
  kit pdf-burst ./documents --recursive
  kit pdf-burst document.pdf -d split -o "part_%d.pdf"
EOF
        return 0
    fi

    local chunk_size=1
    local output_pattern=""
    local output_dir=""
    local recursive=false
    local force=false
    local -a targets=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p|--pages-per-file)
                if [[ $# -lt 2 || ! "$2" =~ ^[0-9]+$ || "$2" -lt 1 ]]; then
                    echo "Error: $1 requires a positive integer" >&2
                    return 2
                fi
                chunk_size="$2"
                shift 2
                ;;
            -o|--output)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a filename pattern" >&2
                    return 2
                fi
                output_pattern="$2"
                shift 2
                ;;
            -d|--output-dir|--dir)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a directory" >&2
                    return 2
                fi
                output_dir="$2"
                shift 2
                ;;
            -r|--recursive) recursive=true; shift ;;
            -f|--force) force=true; shift ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                return 2
                ;;
            *)
                if [[ "$1" =~ ^[0-9]+$ && ${#targets[@]} -gt 0 ]]; then
                    chunk_size="$1"
                else
                    targets+=("$1")
                fi
                shift
                ;;
        esac
    done

    _kit_collect_files _kit_is_pdf_file "$recursive" PDF "${targets[@]}" || return $?
    _kit_exclude_collected_subdir "burst-pdf"
    local -a inputs=("${reply[@]}")
    _kit_check_qpdf || return 1

    local input current_dir index
    local success=0
    local failed=0
    local -a burst_args=()
    for ((index=1; index<=${#inputs[@]}; index++)); do
        input="${inputs[$index]}"
        burst_args=("$input" "$chunk_size")
        [[ "$force" == true ]] && burst_args+=(--force)
        [[ -n "$output_pattern" ]] && burst_args+=(--output "$output_pattern")
        if [[ -n "$output_dir" ]]; then
            if [[ ${#inputs[@]} -eq 1 ]]; then
                current_dir="$output_dir"
            else
                current_dir="$output_dir/${input:t:r}_burst"
            fi
            burst_args+=(--dir "$current_dir")
        else
            _kit_default_result_dir_for_collected "$input" burst-pdf _burst || return 1
            burst_args+=(--dir "$REPLY")
        fi
        if _kit_pdf_burst_one "${burst_args[@]}"; then
            ((success++))
        else
            ((failed++))
        fi
    done
    echo "Processed $success file(s); $failed failed"
    [[ $failed -eq 0 ]]
}
