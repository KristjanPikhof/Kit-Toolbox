# images.sh - Image manipulation utilities using ImageMagick v7
# Category: Image Processing
# Description: ImageMagick v7-based image manipulation and optimization utilities
# Dependencies: imagemagick (v7+ with 'magick' command) for img-* functions except img-rename
# Functions: img-rename, img-resize-width, img-resize-percentage, img-optimize, img-convert, img-optimize-to-webp, img-resize, img-thumbnail, img-resize-exact, img-resize-fill, img-adaptive-resize, img-batch-resize, img-resize-shrink-only, img-resize-colorspace

# Sanitize and rename image files by replacing spaces with underscores/hyphens
# Also supports sequential renaming (e.g., image_1.jpg, image_2.jpg, ...)
img-rename() {
    local dry_run=false
    local separator="_"
    local recursive=false
    local sequential_name=""
    local start_num=1
    local -a targets=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit img-rename <path>... [options]
Description: Sanitize image filenames by replacing spaces/special chars with underscores/hyphens
          Or rename all images sequentially (e.g., image_1.jpg, image_2.jpg)
Options:
  -s, --sep <char>       Separator: '_' (default) or '-' (for sanitize mode)
  -n, --dry-run          Show what would be renamed without making changes
  -r, --recursive        Also include matching files in subfolders
  --name <basename>      Sequential mode: rename to basename_1.ext, basename_2.ext
  --start <number>       Starting number for sequential mode (default: 1)
Examples:
  kit img-rename "photo 1.jpg"              # Sanitize: photo_1.jpg
  kit img-rename "photo 1.jpg" "photo 2.jpg" # Sanitize two files
  kit img-rename "VR (Quest/similar).jpg"   # Sanitize: VR_Quest_similar.jpg
  kit img-rename . --sep "-"                # Sanitize all images in dir, use hyphens
  kit img-rename . --name "photo"           # Sequential: photo_1.jpg, photo_2.png
  kit img-rename . --name "img" --start 10  # Sequential: img_10.jpg, img_11.png
  kit img-rename . --recursive              # Process subdirectories too
  kit img-rename . --dry-run                # Preview changes without renaming
Note: Sanitize mode replaces spaces and special chars (/, (, ), [, ], {, }, :, etc.)
EOF
                return 0
                ;;
            -s|--sep)
                if [[ "$2" == "_" || "$2" == "-" ]]; then
                    separator="$2"
                else
                    echo "Error: Separator must be '_' or '-'" >&2
                    return 2
                fi
                shift 2
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            -r|--recursive)
                recursive=true
                shift
                ;;
            --name)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: --name requires a base name" >&2
                    return 2
                fi
                sequential_name="$2"
                shift 2
                ;;
            --start)
                if [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]]; then
                    start_num="$2"
                else
                    echo "Error: --start requires a non-negative integer" >&2
                    return 2
                fi
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

    if [[ -n "$sequential_name" ]]; then
        if [[ "$sequential_name" == *"/"* || "$sequential_name" == *"\\"* || "$sequential_name" == *".."* ]]; then
            echo "Error: Base name contains invalid characters" >&2
            return 2
        fi
    fi

    _kit_collect_files _kit_is_image_file "$recursive" image "${targets[@]}" || return $?
    local -a files=("${reply[@]}")

    _kit_image_sanitized_path() {
        local old_name="$1"
        local dirname="${old_name%/*}"
        local basename="${old_name##*/}"
        local filename="${basename%.*}"
        local extension="${basename##*.}"

        local trimmed="${filename## }"
        trimmed="${trimmed%% }"
        local character
        for character in '(' ')' '[' ']' '{' '}' '\\' '/' ':' ';' ',' '+' '=' '@' '#' '%' '^' '~' '!' "'" '"' '`' '|' '&' '$' '*' '?' '<' '>'; do
            trimmed="${trimmed//$character/$separator}"
        done
        local new_name="${trimmed// /$separator}"

        while [[ "$new_name" == *"${separator}${separator}"* ]]; do
            new_name="${new_name//${separator}${separator}/$separator}"
        done
        new_name="${new_name#${separator}}"
        new_name="${new_name%${separator}}"

        if [[ "$new_name" == "$filename" ]]; then
            return 1
        fi

        if [[ "$dirname" == "$basename" ]]; then
            print -r -- "${new_name}.${extension}"
        else
            print -r -- "${dirname}/${new_name}.${extension}"
        fi
    }

    local -a outputs=()
    local -A planned_outputs=()
    local file output parent basename extension
    local counter=$start_num
    for file in "${files[@]}"; do
        if [[ -n "$sequential_name" ]]; then
            parent="${file:h}"
            basename="${file:t}"
            extension="${basename##*.}"
            output="${parent}/${sequential_name}_${counter}.${extension}"
            ((counter++))
        else
            output="$(_kit_image_sanitized_path "$file")" || output=""
        fi
        outputs+=("$output")

        [[ -z "$output" || "$output" == "$file" ]] && continue
        if [[ -n "${planned_outputs[${output:A}]:-}" ]]; then
            echo "Error: More than one input would be renamed to '$output'" >&2
            return 1
        fi
        planned_outputs[${output:A}]=1
        if [[ -e "$output" ]]; then
            echo "Error: Rename destination already exists: $output" >&2
            return 1
        fi
    done

    local renamed=0
    local unchanged=0
    local failed=0
    local index
    for ((index=1; index<=${#files[@]}; index++)); do
        file="${files[$index]}"
        output="${outputs[$index]}"
        if [[ -z "$output" || "$output" == "$file" ]]; then
            ((unchanged++))
            continue
        fi
        if [[ "$dry_run" == true ]]; then
            echo "Would rename: $file -> $output"
            ((renamed++))
        elif mv "$file" "$output"; then
            echo "Renamed: $file -> $output"
            ((renamed++))
        else
            echo "Error: Failed to rename '$file'" >&2
            ((failed++))
        fi
    done

    if [[ "$dry_run" == true ]]; then
        echo "Would rename $renamed file(s); $unchanged unchanged"
    else
        echo "Renamed $renamed file(s); $unchanged unchanged"
    fi
    [[ $failed -eq 0 ]]
}

# Image Resize by Width (height auto-calculated to preserve aspect ratio)
img-resize-width() {
    local force=false
    local dry_run=false
    local recursive=false
    local output_dir=""
    local width=""
    local -a targets=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit img-resize-width <width> <path>... [options]
Description: Simple resize by width only, height auto-calculated, preserves aspect ratio
Default output: photo.jpg becomes photo-resized.jpg; a folder uses <folder>/resized/
Optional controls:
  -d, --output-dir DIR  Use a custom result folder
  -f, --force      Overwrite output file if it exists
  -n, --dry-run    Show what would be resized without making changes
  -r, --recursive  Also include matching files in subfolders
Examples:
  kit img-resize-width 800 photo.jpg
  kit img-resize-width 800 photo.jpg cover.png
  kit img-resize-width 1920 . --recursive
  kit img-resize-width 800 . --dry-run
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            -r|--recursive)
                recursive=true
                shift
                ;;
            -d|--output-dir)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a directory" >&2
                    return 2
                fi
                output_dir="$2"
                shift 2
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                return 2
                ;;
            *)
                if [[ -z "$width" ]]; then
                    width="$1"
                else
                    targets+=("$1")
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$width" ]]; then
        echo "Error: Missing width parameter" >&2
        return 2
    fi

    _kit_collect_files _kit_is_image_file "$recursive" image "${targets[@]}" || return $?
    _kit_exclude_collected_subdir "resized"
    local -a files=("${reply[@]}")

    if ! _kit_require magick imagemagick; then
        return 1
    fi
    if [[ "$dry_run" == false ]]; then
        _kit_prepare_output_dir "$output_dir" || return 1
    fi

    _process_single_resize_width() {
        local input="$1"
        local width="$2"
        local force="$3"
        local dry_run="$4"
        local output_dir="$5"

        if ! _is_image_file "$input"; then
            return 0
        fi

        local filename="${input%.*}"
        local extension="${input##*.}"
        _kit_default_output_for_collected "$input" resized -resized "$extension" || return 1
        local output="$REPLY"
        [[ -n "$output_dir" ]] && output="$output_dir/${input:t:r}-resized.${extension}"

        # Prevent double resizing
        if [[ "$filename" == *"-resized" ]]; then
            return 0
        fi

        # Check if output file exists
        if [[ -f "$output" ]]; then
            if [[ "$force" == true ]]; then
                if [[ "$dry_run" == false ]]; then
                    rm -f "$output"
                fi
            else
                echo "⚠️  Skipping: '$input' (output '$output' already exists)" >&2
                return 1
            fi
        fi

        if [[ "$dry_run" == true ]]; then
            echo "Would resize: $input -> $output"
            return 0
        fi

        _kit_prepare_output_dir "${output:h}" || return 1

        if magick "$input" -resize "$width" "$output" 2>/dev/null; then
            echo "✅ Created: $output"
            return 0
        else
            echo "Error: Resize failed for $input" >&2
            return 1
        fi
    }

    local count=0
    local failed=0
    local file
    for file in "${files[@]}"; do
        if _process_single_resize_width "$file" "$width" "$force" "$dry_run" "$output_dir"; then
            ((count++))
        else
            ((failed++))
        fi
    done

    [[ "$dry_run" == true ]] && echo "Would resize $count file(s)" || echo "Resized $count file(s)"
    [[ $failed -eq 0 ]]
}

# Image Resize by Percentage (using Lanczos interpolation for quality - ideal for upscaling)
img-resize-percentage() {
    local force=false
    local dry_run=false
    local recursive=false
    local output_dir=""
    local percentage=""
    local -a targets=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit img-resize-percentage <percentage> <path>... [options]
Description: Resize image by percentage using Lanczos filter for high quality
Features: Uses Lanczos interpolation - ideal for upscaling, reduces blur
Default output: photo.jpg becomes photo-resized.jpg; a folder uses <folder>/resized/
Optional controls:
  -d, --output-dir DIR  Use a custom result folder
  -f, --force      Overwrite output file if it exists
  -n, --dry-run    Show what would be resized without making changes
  -r, --recursive  Also include matching files in subfolders
Examples:
  kit img-resize-percentage 200 photo.jpg    # Double size (upscale)
  kit img-resize-percentage 50 a.jpg b.png   # Resize two files
  kit img-resize-percentage 50 . --recursive # Half size in current dir
  kit img-resize-percentage 150 . --dry-run
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            -r|--recursive)
                recursive=true
                shift
                ;;
            -d|--output-dir)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a directory" >&2
                    return 2
                fi
                output_dir="$2"
                shift 2
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                return 2
                ;;
            *)
                if [[ -z "$percentage" ]]; then
                    percentage="$1"
                else
                    targets+=("$1")
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$percentage" ]]; then
        echo "Error: Missing percentage parameter" >&2
        return 2
    fi

    if ! [[ "$percentage" =~ ^[0-9]+$ ]]; then
        echo "Error: Percentage must be a number (e.g., 50, 150, 200)" >&2
        return 2
    fi

    _kit_collect_files _kit_is_image_file "$recursive" image "${targets[@]}" || return $?
    _kit_exclude_collected_subdir "resized"
    local -a files=("${reply[@]}")

    if ! _kit_require magick imagemagick; then
        return 1
    fi
    if [[ "$dry_run" == false ]]; then
        _kit_prepare_output_dir "$output_dir" || return 1
    fi

    _process_single_resize_percentage() {
        local input="$1"
        local percentage="$2"
        local force="$3"
        local dry_run="$4"
        local output_dir="$5"

        if ! _is_image_file "$input"; then
            return 0
        fi

        local filename="${input%.*}"
        local extension="${input##*.}"
        _kit_default_output_for_collected "$input" resized -resized "$extension" || return 1
        local output="$REPLY"
        [[ -n "$output_dir" ]] && output="$output_dir/${input:t:r}-resized.${extension}"

        # Prevent double resizing
        if [[ "$filename" == *"-resized" ]]; then
            return 0
        fi

        # Check if output file exists
        if [[ -f "$output" ]]; then
            if [[ "$force" == true ]]; then
                if [[ "$dry_run" == false ]]; then
                    rm -f "$output"
                fi
            else
                echo "⚠️  Skipping: '$input' (output '$output' already exists)" >&2
                return 1
            fi
        fi

        if [[ "$dry_run" == true ]]; then
            echo "Would resize: $input -> $output"
            return 0
        fi

        _kit_prepare_output_dir "${output:h}" || return 1

        if magick "$input" -filter Lanczos -resize "$percentage%" "$output" 2>/dev/null; then
            echo "✅ Created: $output (resized to $percentage% with Lanczos filter)"
            return 0
        else
            echo "Error: Percentage resize failed for $input" >&2
            return 1
        fi
    }

    local count=0
    local failed=0
    local file
    for file in "${files[@]}"; do
        if _process_single_resize_percentage "$file" "$percentage" "$force" "$dry_run" "$output_dir"; then
            ((count++))
        else
            ((failed++))
        fi
    done

    [[ "$dry_run" == true ]] && echo "Would resize $count file(s)" || echo "Resized $count file(s)"
    [[ $failed -eq 0 ]]
}

# Helper to check if a file is a supported image
_is_image_file() {
    _kit_is_image_file "$1"
}

# Image Optimization (strips metadata and compresses)
img-optimize() {
    local force=false
    local dry_run=false
    local recursive=false
    local output_dir=""
    local -a targets=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit img-optimize <path>... [options]
Description: Optimize image size without changing its format
Effect: Strips EXIF/metadata and recompresses the image at quality 85%
Note: Keeps the original format (PNG stays PNG, JPG stays JPG)
Default output: photo.jpg becomes photo-optimized.jpg; a folder uses <folder>/optimized/
Optional controls:
  -d, --output-dir DIR  Use a custom result folder
  -f, --force      Overwrite output file if it exists
  -n, --dry-run    Show what would be optimized without making changes
  -r, --recursive  Also include matching files in subfolders
Examples:
  kit img-optimize photo.jpg
  kit img-optimize photo.jpg logo.png
  kit img-optimize logo.png          # Creates logo-optimized.png
  kit img-optimize . --recursive --dry-run
  kit img-optimize image.png --force
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            -r|--recursive)
                recursive=true
                shift
                ;;
            -d|--output-dir)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a directory" >&2
                    return 2
                fi
                output_dir="$2"
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

    _kit_collect_files _kit_is_image_file "$recursive" image "${targets[@]}" || return $?
    _kit_exclude_collected_subdir "optimized"
    local -a files=("${reply[@]}")

    if ! _kit_require magick imagemagick; then
        return 1
    fi
    if [[ "$dry_run" == false ]]; then
        _kit_prepare_output_dir "$output_dir" || return 1
    fi

    _process_single_optimize() {
        local input="$1"
        local force="$2"
        local dry_run="$3"
        local output_dir="$4"

        if ! _is_image_file "$input"; then
            return 0
        fi

        local filename="${input%.*}"
        local extension="${input##*.}"
        _kit_default_output_for_collected "$input" optimized -optimized "$extension" || return 1
        local output="$REPLY"
        [[ -n "$output_dir" ]] && output="$output_dir/${input:t:r}-optimized.${extension}"

        # Prevent double optimization
        if [[ "$filename" == *"-optimized" ]]; then
            return 0
        fi

        # Check if output file exists
        if [[ -f "$output" ]]; then
            if [[ "$force" == true ]]; then
                if [[ "$dry_run" == false ]]; then
                    rm -f "$output"
                fi
            else
                echo "⚠️  Skipping: '$input' (output '$output' already exists)" >&2
                return 1
            fi
        fi

        if [[ "$dry_run" == true ]]; then
            echo "Would optimize: $input -> $output"
            return 0
        fi

        _kit_prepare_output_dir "${output:h}" || return 1

        if magick "$input" -strip -quality 85 "$output" 2>/dev/null; then
            echo "✅ Created: $output"
            return 0
        else
            echo "Error: Optimization failed for $input" >&2
            return 1
        fi
    }

    local count=0
    local failed=0
    local file
    for file in "${files[@]}"; do
        if _process_single_optimize "$file" "$force" "$dry_run" "$output_dir"; then
            ((count++))
        else
            ((failed++))
        fi
    done

    [[ "$dry_run" == true ]] && echo "Would optimize $count file(s)" || echo "Optimized $count file(s)"
    [[ $failed -eq 0 ]]
}

# Unified Image Format Conversion
img-convert() {
    local from_format=""
    local to_format=""
    local recursive=false
    local force=false
    local dry_run=false
    local output_dir=""
    local -a targets=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit img-convert <from_format> <to_format> [path]... [options]
Description: Convert one or more images to another format
Supported formats: png, jpg, jpeg, webp, heic, avif, bmp, tiff, gif, pdf
Default output: photo.jpg converted to WebP becomes photo.webp; a folder uses <folder>/converted/
Optional controls:
  -d, --output-dir DIR  Use a custom result folder
  -r, --recursive       Also include matching files in subfolders
  -f, --force           Overwrite existing outputs
  -n, --dry-run         Show planned conversions
Examples:
  kit img-convert png jpg photo.png
  kit img-convert png jpg a.png b.png
  kit img-convert heic webp ./old --recursive
  kit img-convert jpg png . --output-dir ./converted
EOF
                return 0
                ;;
            -d|--output-dir)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a directory" >&2
                    return 2
                fi
                output_dir="$2"
                shift 2
                ;;
            -r|--recursive) recursive=true; shift ;;
            -f|--force) force=true; shift ;;
            -n|--dry-run) dry_run=true; shift ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                return 2
                ;;
            *)
                if [[ -z "$from_format" ]]; then
                    from_format="$1"
                elif [[ -z "$to_format" ]]; then
                    to_format="$1"
                else
                    targets+=("$1")
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$from_format" || -z "$to_format" ]]; then
        echo "Error: Missing format parameters" >&2
        return 2
    fi

    local -a supported_formats=(png jpg jpeg webp heic avif bmp tiff gif pdf)
    if (( ! supported_formats[(Ie)${from_format:l}] || ! supported_formats[(Ie)${to_format:l}] )); then
        echo "Error: Unsupported format. Use: ${supported_formats[*]}" >&2
        return 2
    fi

    [[ ${#targets[@]} -eq 0 ]] && targets=(.)

    _kit_matches_conversion_source() { _kit_file_has_extension "$1" "$from_format"; }
    _kit_collect_files _kit_matches_conversion_source "$recursive" ".${from_format:l} image" "${targets[@]}" || return $?
    _kit_exclude_collected_subdir "converted"
    local -a input_files=("${reply[@]}")

    _kit_require magick imagemagick || return 1
    if [[ "$dry_run" == false ]]; then
        _kit_prepare_output_dir "$output_dir" || return 1
    fi

    local file filename output
    local success=0
    local failed=0
    local -A outputs=()
    local -a planned_outputs=()
    for file in "${input_files[@]}"; do
        filename="${file:t:r}"
        if [[ -n "$output_dir" ]]; then
            output="$output_dir/$filename.${to_format:l}"
        else
            _kit_default_output_for_collected "$file" converted "" "${to_format:l}" || return 1
            output="$REPLY"
        fi
        if [[ -n "${outputs[${output:A}]:-}" ]]; then
            echo "Error: Multiple inputs would create '$output'" >&2
            return 1
        fi
        outputs[${output:A}]=1
        if [[ -e "$output" && "$force" != true ]]; then
            echo "Error: Output file '$output' already exists. Use --force to overwrite." >&2
            return 1
        fi
        planned_outputs+=("$output")
    done

    local index
    for ((index=1; index<=${#input_files[@]}; index++)); do
        file="${input_files[$index]}"
        output="${planned_outputs[$index]}"
        if [[ "$dry_run" == true ]]; then
            echo "Would convert: $file -> $output"
            ((success++))
            continue
        fi
        mkdir -p "${output:h}" || { echo "Error: Cannot create '${output:h}'" >&2; ((failed++)); continue; }
        if magick "$file" -quality 90 -auto-orient "$output" 2>/dev/null; then
            echo "Created: $output"
            ((success++))
        else
            echo "Error: Conversion failed for '$file'" >&2
            ((failed++))
        fi
    done
    echo "Converted $success file(s); $failed failed"
    [[ $failed -eq 0 ]]
}

# Optimize images to WebP format with maximum quality and compression
img-optimize-to-webp() {
    local recursive=false
    local force=false
    local dry_run=false
    local output_dir=""
    local -a targets=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit img-optimize-to-webp [path]... [options]
Description: Convert one or more supported images to optimized WebP
Features: Maximum quality (90), best compression (method=6, pass=10), sharp-yuv enabled
Supported input: PNG, JPG, JPEG, HEIC
Default output: photo.jpg becomes photo.webp; a folder uses <folder>/optimized/
Optional controls:
  -d, --output-dir DIR  Use a custom result folder
  -r, --recursive       Also include matching files in subfolders
  -f, --force           Overwrite existing outputs
  -n, --dry-run         Show planned conversions
Examples:
  kit img-optimize-to-webp photo.jpg   # Creates photo.webp beside the source
  kit img-optimize-to-webp a.jpg b.png
  kit img-optimize-to-webp             # Current directory
  kit img-optimize-to-webp ./pics --recursive
EOF
                return 0
                ;;
            -d|--output-dir)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a directory" >&2
                    return 2
                fi
                output_dir="$2"
                shift 2
                ;;
            -r|--recursive) recursive=true; shift ;;
            -f|--force) force=true; shift ;;
            -n|--dry-run) dry_run=true; shift ;;
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

    [[ ${#targets[@]} -eq 0 ]] && targets=(.)
    _kit_collect_files _kit_is_webp_source_file "$recursive" image "${targets[@]}" || return $?
    _kit_exclude_collected_subdir "optimized"
    local -a files=("${reply[@]}")
    _kit_require magick imagemagick || return 1

    local file output
    local -a outputs=()
    local -A seen_outputs=()
    for file in "${files[@]}"; do
        if [[ -n "$output_dir" ]]; then
            output="$output_dir/${file:t:r}.webp"
        else
            _kit_default_output_for_collected "$file" optimized "" webp || return 1
            output="$REPLY"
        fi
        if [[ -n "${seen_outputs[${output:A}]:-}" ]]; then
            echo "Error: Multiple inputs would create '$output'" >&2
            return 1
        fi
        seen_outputs[${output:A}]=1
        if [[ -e "$output" && "$force" != true ]]; then
            echo "Error: Output file '$output' already exists. Use --force to overwrite." >&2
            return 1
        fi
        outputs+=("$output")
    done

    local success=0
    local failed=0
    local index
    for ((index=1; index<=${#files[@]}; index++)); do
        file="${files[$index]}"
        output="${outputs[$index]}"
        if [[ "$dry_run" == true ]]; then
            echo "Would optimize: $file -> $output"
            ((success++))
            continue
        fi
        mkdir -p "${output:h}" || { echo "Error: Cannot create '${output:h}'" >&2; ((failed++)); continue; }
        if magick "$file" -quality 90 -define webp:method=6 -define webp:pass=10 -define webp:use-sharp-yuv=1 "$output" 2>/dev/null; then
            echo "Created: $output"
            ((success++))
        else
            echo "Error: Optimization failed for '$file'" >&2
            ((failed++))
        fi
    done
    echo "Optimized $success file(s); $failed failed"
    [[ $failed -eq 0 ]]
}

# ============================================================================
# ImageMagick Advanced Resize Functions (Safety-First Series)
# ============================================================================

# General image resize preserving aspect ratio
img-resize() {
    local force=false
    local dry_run=false
    local recursive=false
    local output_dir=""
    local size=""
    local -a targets=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit img-resize <width>x<height> <path>... [options]
Description: Resize image preserving aspect ratio, output has -resized suffix
Default output: photo.jpg becomes photo-resized.jpg; a folder uses <folder>/resized/
Optional controls:
  -d, --output-dir DIR  Use a custom result folder
  -f, --force      Overwrite output file if it exists
  -n, --dry-run    Show what would be resized without making changes
  -r, --recursive  Also include matching files in subfolders
Examples:
  kit img-resize 800x600 photo.jpg        # Fit within 800x600
  kit img-resize 800x600 photo.jpg cover.png
  kit img-resize 1024 . --recursive       # Width 1024 in current dir
  kit img-resize 1920x1080 . --dry-run
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            -n|--dry-run)
                dry_run=true
                shift
                ;;
            -r|--recursive)
                recursive=true
                shift
                ;;
            -d|--output-dir)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a directory" >&2
                    return 2
                fi
                output_dir="$2"
                shift 2
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                return 2
                ;;
            *)
                if [[ -z "$size" ]]; then
                    size="$1"
                else
                    targets+=("$1")
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$size" ]]; then
        echo "Error: Missing size parameter" >&2
        return 2
    fi

    _kit_collect_files _kit_is_image_file "$recursive" image "${targets[@]}" || return $?
    _kit_exclude_collected_subdir "resized"
    local -a files=("${reply[@]}")

    if ! _kit_require magick imagemagick; then
        return 1
    fi
    if [[ "$dry_run" == false ]]; then
        _kit_prepare_output_dir "$output_dir" || return 1
    fi

    _process_single_resize() {
        local input="$1"
        local size="$2"
        local force="$3"
        local dry_run="$4"
        local output_dir="$5"

        if ! _is_image_file "$input"; then
            return 0
        fi

        local filename="${input%.*}"
        local extension="${input##*.}"
        _kit_default_output_for_collected "$input" resized -resized "$extension" || return 1
        local output="$REPLY"
        [[ -n "$output_dir" ]] && output="$output_dir/${input:t:r}-resized.${extension}"

        # Prevent double resizing
        if [[ "$filename" == *"-resized" ]]; then
            return 0
        fi

        # Check if output file exists
        if [[ -f "$output" ]]; then
            if [[ "$force" == true ]]; then
                if [[ "$dry_run" == false ]]; then
                    rm -f "$output"
                fi
            else
                echo "⚠️  Skipping: '$input' (output '$output' already exists)" >&2
                return 1
            fi
        fi

        if [[ "$dry_run" == true ]]; then
            echo "Would resize: $input -> $output"
            return 0
        fi

        _kit_prepare_output_dir "${output:h}" || return 1

        if magick "$input" -resize "$size" "$output" 2>/dev/null; then
            echo "✅ Created: $output"
            return 0
        else
            echo "Error: Resize failed for $input" >&2
            return 1
        fi
    }

    local count=0
    local failed=0
    local file
    for file in "${files[@]}"; do
        if _process_single_resize "$file" "$size" "$force" "$dry_run" "$output_dir"; then
            ((count++))
        else
            ((failed++))
        fi
    done

    [[ "$dry_run" == true ]] && echo "Would resize $count file(s)" || echo "Resized $count file(s)"
    [[ $failed -eq 0 ]]
}

_kit_run_image_resize_many() {
    local mode="$1"
    shift

    local result_folder
    case "$mode" in
        thumbnail) result_folder="thumbnails" ;;
        exact) result_folder="resized-exact" ;;
        fill) result_folder="resized-fill" ;;
        adaptive) result_folder="adaptive-resized" ;;
        shrink) result_folder="shrink-only" ;;
        colorspace) result_folder="colorspace-resized" ;;
    esac

    local size=""
    local recursive=false
    local force=false
    local dry_run=false
    local output_dir=""
    local colorspace="lab"
    local -a targets=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -r|--recursive) recursive=true; shift ;;
            -f|--force) force=true; shift ;;
            -n|--dry-run) dry_run=true; shift ;;
            -d|--output-dir)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a directory" >&2
                    return 2
                fi
                output_dir="$2"
                shift 2
                ;;
            -m|--colorspace)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires rgb, lab, or luv" >&2
                    return 2
                fi
                colorspace="$2"
                shift 2
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                return 2
                ;;
            *)
                if [[ -z "$size" ]]; then
                    size="$1"
                else
                    targets+=("$1")
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$size" ]]; then
        echo "Error: Missing size" >&2
        return 2
    fi
    if [[ "$mode" == colorspace && ! "$colorspace" =~ ^(rgb|lab|luv)$ ]]; then
        echo "Error: Invalid colorspace '$colorspace'. Use: rgb, lab, or luv" >&2
        return 2
    fi

    _kit_collect_files _kit_is_image_file "$recursive" image "${targets[@]}" || return $?
    _kit_exclude_collected_subdir "$result_folder"
    local -a files=("${reply[@]}")
    _kit_require magick imagemagick || return 1

    local file output
    local -a outputs=()
    local -A seen_outputs=()
    for file in "${files[@]}"; do
        if [[ -n "$output_dir" ]]; then
            output="$output_dir/${file:t:r}-resized.${file:e}"
        else
            _kit_default_output_for_collected "$file" "$result_folder" -resized "${file:e}" || return 1
            output="$REPLY"
        fi
        if [[ -n "${seen_outputs[${output:A}]:-}" ]]; then
            echo "Error: Multiple inputs would create '$output'" >&2
            return 1
        fi
        seen_outputs[${output:A}]=1
        if [[ -e "$output" && "$force" != true ]]; then
            echo "Error: Output file '$output' already exists. Use --force to overwrite." >&2
            return 1
        fi
        outputs+=("$output")
    done

    local success=0
    local failed=0
    local index
    for ((index=1; index<=${#files[@]}; index++)); do
        file="${files[$index]}"
        output="${outputs[$index]}"
        if [[ "$dry_run" == true ]]; then
            echo "Would resize: $file -> $output"
            ((success++))
            continue
        fi
        mkdir -p "${output:h}" || { echo "Error: Cannot create '${output:h}'" >&2; ((failed++)); continue; }
        case "$mode" in
            thumbnail) magick "$file" -thumbnail "$size" -strip "$output" 2>/dev/null ;;
            exact) magick "$file" -resize "${size}!" "$output" 2>/dev/null ;;
            fill) magick "$file" -resize "${size}^" -gravity center -extent "$size" "$output" 2>/dev/null ;;
            adaptive) magick "$file" -adaptive-resize "$size" "$output" 2>/dev/null ;;
            shrink) magick "$file" -resize "${size}>" "$output" 2>/dev/null ;;
            colorspace) magick "$file" -colorspace "$colorspace" -filter Lanczos -resize "$size" -colorspace sRGB "$output" 2>/dev/null ;;
        esac
        if [[ $? -eq 0 ]]; then
            echo "Created: $output"
            ((success++))
        else
            rm -f "$output"
            echo "Error: Resize failed for '$file'" >&2
            ((failed++))
        fi
    done

    echo "Resized $success file(s); $failed failed"
    [[ $failed -eq 0 ]]
}

# Fast thumbnail generation with profile stripping
img-thumbnail() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit img-thumbnail <width>x<height> <path>... [options]
Description: Create fast thumbnails and strip image profiles
Default output: photo.jpg becomes photo-resized.jpg; a folder uses <folder>/thumbnails/
Optional controls:
  -d, --output-dir DIR  Use a custom result folder
  -r, --recursive       Also include matching files in subfolders
  -f, --force           Overwrite existing outputs
  -n, --dry-run         Show planned outputs
Examples:
  kit img-thumbnail 200x200 photo.jpg
  kit img-thumbnail 200x200 a.jpg b.png
  kit img-thumbnail 300x300 ./images --recursive
EOF
        return 0
    fi
    _kit_run_image_resize_many thumbnail "$@"
}

# Force exact dimensions (ignore aspect ratio)
img-resize-exact() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit img-resize-exact <width>x<height> <path>... [options]
Description: Force exact dimensions, which may distort the image
Default output: photo.jpg becomes photo-resized.jpg; a folder uses <folder>/resized-exact/
Optional controls:
  -d, --output-dir DIR  Use a custom result folder
  -r, --recursive       Also include matching files in subfolders
  -f, --force           Overwrite existing outputs
  -n, --dry-run         Show planned outputs
Examples:
  kit img-resize-exact 800x600 photo.jpg
  kit img-resize-exact 800x600 a.jpg b.png
  kit img-resize-exact 1024x768 ./images --recursive
EOF
        return 0
    fi
    _kit_run_image_resize_many exact "$@"
}

# Resize to fill space and crop excess
img-resize-fill() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit img-resize-fill <width>x<height> <path>... [options]
Description: Resize to fill an area, center the image, and crop excess
Default output: photo.jpg becomes photo-resized.jpg; a folder uses <folder>/resized-fill/
Optional controls:
  -d, --output-dir DIR  Use a custom result folder
  -r, --recursive       Also include matching files in subfolders
  -f, --force           Overwrite existing outputs
  -n, --dry-run         Show planned outputs
Examples:
  kit img-resize-fill 800x600 photo.jpg
  kit img-resize-fill 800x600 a.jpg b.png
  kit img-resize-fill 1024x1024 ./images --recursive
EOF
        return 0
    fi
    _kit_run_image_resize_many fill "$@"
}

# Quality resize without blurring (adaptive/mesh interpolation)
img-adaptive-resize() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit img-adaptive-resize <width>x<height> <path>... [options]
Description: Resize using mesh interpolation for small adjustments and magnification
Default output: photo.jpg becomes photo-resized.jpg; a folder uses <folder>/adaptive-resized/
Optional controls:
  -d, --output-dir DIR  Use a custom result folder
  -r, --recursive       Also include matching files in subfolders
  -f, --force           Overwrite existing outputs
  -n, --dry-run         Show planned outputs
Examples:
  kit img-adaptive-resize 800x600 photo.jpg
  kit img-adaptive-resize 800x600 a.jpg b.png
  kit img-adaptive-resize 1.5x ./images --recursive
EOF
        return 0
    fi
    _kit_run_image_resize_many adaptive "$@"
}

# Batch resize multiple images (sequential, safety-first)
img-batch-resize() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit img-batch-resize <width>x<height> <path>... [options]
Description: Compatibility alias for img-resize
Default output: photo.jpg becomes photo-resized.jpg; a folder uses <folder>/resized/
Optional controls:
  -d, --output-dir DIR  Use a custom result folder
  -r, --recursive       Also include matching files in subfolders
  -f, --force           Overwrite existing outputs
  -n, --dry-run         Show planned outputs
Examples:
  kit img-batch-resize 800x600 *.jpg
  kit img-batch-resize 1024x1024 ./images --recursive
EOF
        return 0
    fi
    img-resize "$@"
}

# Only shrink, never enlarge
img-resize-shrink-only() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit img-resize-shrink-only <width>x<height> <path>... [options]
Description: Resize images only when they are larger than the requested size
Default output: photo.jpg becomes photo-resized.jpg; a folder uses <folder>/shrink-only/
Optional controls:
  -d, --output-dir DIR  Use a custom result folder
  -r, --recursive       Also include matching files in subfolders
  -f, --force           Overwrite existing outputs
  -n, --dry-run         Show planned outputs
Examples:
  kit img-resize-shrink-only 800x600 photo.jpg
  kit img-resize-shrink-only 800x600 a.jpg b.png
  kit img-resize-shrink-only 1024 ./images --recursive
EOF
        return 0
    fi
    _kit_run_image_resize_many shrink "$@"
}

# Resize with colorspace correction for better quality
img-resize-colorspace() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit img-resize-colorspace <width>x<height> <path>... [options]
Description: Resize with colorspace correction
Default output: photo.jpg becomes photo-resized.jpg; a folder uses <folder>/colorspace-resized/
Colorspace options:
  -m, --colorspace rgb  Linear RGB
  -m, --colorspace lab  LAB perceptual (default)
  -m, --colorspace luv  LUV perceptual
Other options:
  -d, --output-dir DIR  Use a custom result folder
  -r, --recursive       Also include matching files in subfolders
  -f, --force           Overwrite existing outputs
  -n, --dry-run         Show planned outputs
Examples:
  kit img-resize-colorspace 800x600 photo.jpg
  kit img-resize-colorspace 800x600 a.jpg b.png -m lab
  kit img-resize-colorspace 1024 ./images -m rgb --recursive
EOF
        return 0
    fi
    _kit_run_image_resize_many colorspace "$@"
}
