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
    local target=""
    local recursive=false
    local sequential_name=""
    local start_num=1

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit img-rename <file|directory> [options]
Description: Sanitize image filenames by replacing spaces/special chars with underscores/hyphens
          Or rename all images sequentially (e.g., image_1.jpg, image_2.jpg)
Options:
  -s, --sep <char>       Separator: '_' (default) or '-' (for sanitize mode)
  -n, --dry-run          Show what would be renamed without making changes
  -r, --recursive        Process directories recursively
  --name <basename>      Sequential mode: rename to basename_1.ext, basename_2.ext
  --start <number>       Starting number for sequential mode (default: 1)
Examples:
  kit img-rename "photo 1.jpg"              # Sanitize: photo_1.jpg
  kit img-rename "VR (Quest/similar).jpg"   # Sanitize: VR_Quest_similar.jpg
  kit img-rename "  my image.png "          # Sanitize: my_image.png (trims spaces)
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
                sequential_name="$2"
                shift 2
                ;;
            --start)
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    start_num="$2"
                else
                    echo "Error: Start number must be a positive integer" >&2
                    return 2
                fi
                shift 2
                ;;
            *)
                if [[ -z "$target" ]]; then
                    target="$1"
                fi
                shift
                ;;
        esac
    done

    # Input validation
    if [[ -z "$target" ]]; then
        echo "Error: Missing target file or directory" >&2
        return 2
    fi

    # Sequential mode only works with directories
    if [[ -n "$sequential_name" && ! -d "$target" ]]; then
        echo "Error: Sequential mode (--name) requires a directory target" >&2
        return 2
    fi

    # Sanitize filename to prevent injection attacks
    # Check for shell metacharacters that could be dangerous
    if [[ "$target" == *"|"* ]] || [[ "$target" == *"&"* ]] || \
       [[ "$target" == *'$'* ]] || [[ "$target" == *";"* ]] || \
       [[ "$target" == *"<"* ]] || [[ "$target" == *">"* ]]; then
        echo "Error: Target contains invalid characters" >&2
        return 2
    fi

    # Check for path traversal
    if [[ "$target" == *"../"* ]] || [[ "$target" == *"/.."* ]]; then
        echo "Error: Path contains traversal sequences" >&2
        return 2
    fi

    # Validate sequential_name doesn't have invalid characters
    if [[ -n "$sequential_name" ]]; then
        if [[ "$sequential_name" == *"|"* ]] || [[ "$sequential_name" == *"&"* ]] || \
           [[ "$sequential_name" == *'$'* ]] || [[ "$sequential_name" == *";"* ]] || \
           [[ "$sequential_name" == *"<"* ]] || [[ "$sequential_name" == *">"* ]] || \
           [[ "$sequential_name" == *"/"* ]] || [[ "$sequential_name" == *"\\"* ]]; then
            echo "Error: Base name contains invalid characters" >&2
            return 2
        fi
        # Also check for path traversal in base name
        if [[ "$sequential_name" == *".."* ]]; then
            echo "Error: Base name cannot contain '..'" >&2
            return 2
        fi
    fi

    # Supported image extensions
    local -a extensions=(jpg jpeg png gif webp bmp tiff tif heic heif avif svg ico)
    local -a extensions_upper=(JPG JPEG PNG GIF WEBP BMP TIFF TIF HEIC HEIF AVIF SVG ICO)

    # Function to generate new filename
    _generate_new_name() {
        local old_name="$1"
        local dirname="${old_name%/*}"
        local basename="${old_name##*/}"
        local filename="${basename%.*}"
        local extension="${basename##*.}"
        extension="${extension% }"
        extension="${extension# }"

        # Check if it's an image file (by extension)
        local is_image=false
        for ext in "${extensions[@]}" "${extensions_upper[@]}"; do
            if [[ "${extension:l}" == "${ext:l}" ]]; then
                is_image=true
                break
            fi
        done

        if [[ "$is_image" == false ]]; then
            echo ""
            return
        fi

        # Trim leading and trailing spaces
        local trimmed="${filename## }"      # Remove leading spaces
        trimmed="${trimmed%% }"              # Remove trailing spaces

        # Replace problematic special characters with separator
        # These cause issues in shells or filesystems
        trimmed="${trimmed//\(/$separator}"   # (
        trimmed="${trimmed//\)/$separator}"   # )
        trimmed="${trimmed//\[/$separator}"   # [
        trimmed="${trimmed//\]/$separator}"   # ]
        trimmed="${trimmed//\{/$separator}"   # {
        trimmed="${trimmed//\}/$separator}"   # }
        trimmed="${trimmed//\\/$separator}"   # backslash
        trimmed="${trimmed//\//$separator}"   # forward slash (dangerous!)
        trimmed="${trimmed//:/$separator}"    # : (problematic on macOS/Windows)
        trimmed="${trimmed//;/$separator}"    # ;
        trimmed="${trimmed//,/$separator}"    # comma (optional)
        trimmed="${trimmed//+/$separator}"    # +
        trimmed="${trimmed//=/$separator}"    # =
        trimmed="${trimmed//@/$separator}"    # @
        trimmed="${trimmed//#/$separator}"    # #
        trimmed="${trimmed//%/$separator}"    # %
        trimmed="${trimmed//^/$separator}"    # ^
        trimmed="${trimmed//~/$separator}"    # ~
        trimmed="${trimmed//\!/$separator}"   # !
        trimmed="${trimmed//\'/$separator}"   # '
        trimmed="${trimmed//\"/$separator}"   # "
        trimmed="${trimmed//\`/$separator}"   # backtick
        trimmed="${trimmed//|/$separator}"    # |
        trimmed="${trimmed//&/$separator}"    # &
        trimmed="${trimmed//\$/$separator}"   # $
        trimmed="${trimmed//\*/$separator}"   # *
        trimmed="${trimmed//\?/$separator}"   # ? (escaped for zsh/bash glob)
        trimmed="${trimmed//</$separator}"    # <
        trimmed="${trimmed//>/$separator}"    # >

        # Replace spaces with separator (after other chars to handle properly)
        local new_name="${trimmed// /$separator}"

        # Replace multiple consecutive separators with single one
        while [[ "$new_name" == *"${separator}${separator}"* ]]; do
            new_name="${new_name//${separator}${separator}/$separator}"
        done

        # Remove separator from start/end if present
        new_name="${new_name#${separator}}"
        new_name="${new_name%${separator}}"

        # If nothing changed, return empty
        if [[ "$new_name" == "$filename" ]]; then
            echo ""
            return
        fi

        # Construct full new path
        if [[ "$dirname" == "$basename" ]]; then
            echo "${new_name}.${extension}"
        else
            echo "${dirname}/${new_name}.${extension}"
        fi
    }

    # Process single file
    if [[ -f "$target" ]]; then
        local new_name
        new_name="$(_generate_new_name "$target")"

        if [[ -z "$new_name" ]]; then
            if [[ "$target" != *" "* ]]; then
                echo "No changes needed: $target (already sanitized)"
            else
                echo "Skipped: $target (not an image file)"
            fi
            return 0
        fi

        # Check if target already exists
        if [[ -e "$new_name" ]]; then
            echo "Error: Cannot rename '$target' to '$new_name' - target already exists" >&2
            return 1
        fi

        if [[ "$dry_run" == true ]]; then
            echo "Would rename: $target -> $new_name"
        else
            if mv "$target" "$new_name"; then
                echo "Renamed: $target -> $new_name"
            else
                echo "Error: Failed to rename '$target'" >&2
                return 1
            fi
        fi
        return 0
    fi

    # Process directory
    if [[ -d "$target" ]]; then
        # Sequential mode: rename all images to basename_N.ext
        if [[ -n "$sequential_name" ]]; then
            local count=0
            local failed=0
            local counter=$start_num

            # Build find command based on recursive flag
            local find_pattern="$target/*"
            if [[ "$recursive" == true ]]; then
                find_pattern="$target/**/*"
            fi

            # Use setopt for nullglob in zsh
            setopt local_options nullglob 2>/dev/null || true

            # Collect and sort files for consistent ordering
            local -a files=()
            for file in $~find_pattern; do
                [[ -f "$file" ]] || continue

                # Check if it's an image file
                local ext="${file##*.}"
                local is_image=false
                for e in "${extensions[@]}" "${extensions_upper[@]}"; do
                    if [[ "${ext:l}" == "${e:l}" ]]; then
                        is_image=true
                        break
                    fi
                done

                [[ "$is_image" == true ]] && files+=("$file")
            done

            # Sort files for consistent ordering
            files=("${(@o)files}")

            for file in "${files[@]}"; do
                local ext="${file##*.}"
                local new_name="${target}/${sequential_name}_${counter}.${ext}"

                # Check if target already exists
                if [[ -e "$new_name" && "$new_name" != "$file" ]]; then
                    echo "Warning: '$file' -> '$new_name' - target exists, skipping" >&2
                    ((failed++))
                    ((counter++))
                    continue
                fi

                # Skip if no change needed
                if [[ "$new_name" == "$file" ]]; then
                    ((counter++))
                    continue
                fi

                if [[ "$dry_run" == true ]]; then
                    echo "Would rename: $file -> $new_name"
                    ((count++))
                else
                    if mv "$file" "$new_name"; then
                        echo "Renamed: $file -> $new_name"
                        ((count++))
                    else
                        echo "Error: Failed to rename '$file'" >&2
                        ((failed++))
                    fi
                fi
                ((counter++))
            done

            echo ""
            if [[ "$dry_run" == true ]]; then
                echo "Would rename $count file(s)"
            else
                echo "Renamed $count file(s) to ${sequential_name}_N format"
            fi
            if [[ $failed -gt 0 ]]; then
                echo "Failed: $failed file(s)" >&2
                return 1
            fi
            return 0
        fi

        # Sanitize mode (default)
        local count=0
        local skipped=0
        local failed=0

        # Build find command based on recursive flag
        local find_pattern="$target/*"
        if [[ "$recursive" == true ]]; then
            find_pattern="$target/**/*"
        fi

        # Use setopt for nullglob in zsh
        setopt local_options nullglob 2>/dev/null || true

        for file in $~find_pattern; do
            [[ -f "$file" ]] || continue

            local new_name
            new_name="$(_generate_new_name "$file")"

            if [[ -z "$new_name" ]]; then
                ((skipped++))
                continue
            fi

            # Check if target already exists
            if [[ -e "$new_name" ]]; then
                echo "Warning: '$file' -> '$new_name' - target exists, skipping" >&2
                ((failed++))
                continue
            fi

            if [[ "$dry_run" == true ]]; then
                echo "Would rename: $file -> $new_name"
                ((count++))
            else
                if mv "$file" "$new_name"; then
                    echo "Renamed: $file -> $new_name"
                    ((count++))
                else
                    echo "Error: Failed to rename '$file'" >&2
                    ((failed++))
                fi
            fi
        done

        echo ""
        if [[ "$dry_run" == true ]]; then
            echo "Would rename $count file(s)"
        else
            echo "Renamed $count file(s)"
        fi
        if [[ $skipped -gt 0 ]]; then
            echo "Skipped $skipped file(s) (no changes needed or not images)"
        fi
        if [[ $failed -gt 0 ]]; then
            echo "Failed: $failed file(s)" >&2
            return 1
        fi
        return 0
    fi

    # Target doesn't exist
    echo "Error: Target '$target' does not exist" >&2
    return 1
}

# Helper function to print ImageMagick installation instructions
# Usage: _kit_imagemagick_install_help <mode>
#   mode: "install" or "upgrade"
_kit_imagemagick_install_help() {
    local mode="$1"
    local action="install"
    local preface="Install with:"

    if [[ "$mode" == "upgrade" ]]; then
        action="upgrade"
        preface="Upgrade instructions:"
    fi

    case "$(uname -s)" in
        Darwin)
            if [[ "$mode" == "upgrade" ]]; then
                echo "  brew $action imagemagick" >&2
                echo "  # If that doesn't work, try:" >&2
                echo "  brew reinstall imagemagick" >&2
            else
                echo "  brew $action imagemagick" >&2
            fi
            ;;
        Linux)
            echo "  # Ubuntu/Debian - add official PPA for v7:" >&2
            echo "  sudo add-apt-repository ppa:imagemagick/ppa" >&2
            if [[ "$mode" == "upgrade" ]]; then
                echo "  sudo apt update" >&2
                echo "  sudo apt $action imagemagick" >&2
            else
                echo "  sudo apt update && sudo apt $action imagemagick" >&2
            fi
            echo "" >&2
            echo "  # Fedora:" >&2
            echo "  sudo dnf $action ImageMagick" >&2
            echo "" >&2
            echo "  # Arch:" >&2
            echo "  sudo pacman -S imagemagick" >&2
            ;;
        *)
            echo "  See: https://imagemagick.org/script/download.php" >&2
            ;;
    esac
}

# Helper function to check ImageMagick v7 availability
_kit_require_imagemagick() {
    # Check for v7 (magick command)
    if command -v magick > /dev/null 2>&1; then
        return 0
    fi

    # Check for v6 (convert command) and provide migration help
    if command -v convert > /dev/null 2>&1; then
        echo "Error: ImageMagick v6 detected. Kit requires ImageMagick v7+." >&2
        echo "" >&2
        echo "You have ImageMagick v6 (uses 'convert' command)." >&2
        echo "Kit's image functions require v7+ (uses 'magick' command)." >&2
        echo "" >&2
        echo "Upgrade instructions:" >&2
        _kit_imagemagick_install_help "upgrade"
        return 1
    fi

    # No ImageMagick found at all
    echo "Error: ImageMagick not found. Install v7+ for image functions." >&2
    echo "" >&2
    echo "Install with:" >&2
    _kit_imagemagick_install_help "install"
    return 1
}

# Image Resize by Width (height auto-calculated to preserve aspect ratio)
img-resize-width() {
    local force=false
    local dry_run=false
    local recursive=false
    local width=""
    local target=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit img-resize-width <width> <file|directory> [options]
Description: Simple resize by width only, height auto-calculated, preserves aspect ratio
Options:
  -f, --force      Overwrite output file if it exists
  -n, --dry-run    Show what would be resized without making changes
  -r, --recursive  Process directories recursively
Examples:
  kit img-resize-width 800 photo.jpg
  kit img-resize-width 1920 . --recursive
  kit img-resize-width 800 . --dry-run
Output: Creates photo-resized.jpg
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
            *)
                if [[ -z "$width" ]]; then
                    width="$1"
                elif [[ -z "$target" ]]; then
                    target="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$width" ]]; then
        echo "Error: Missing width parameter" >&2
        return 2
    fi

    if [[ -z "$target" ]]; then
        echo "Error: Missing target file or directory" >&2
        return 2
    fi

    # Sanitize filename to prevent injection attacks
    # Note: Using fixed character class - backslash-escape inside [] has inconsistent behavior
    if [[ "$target" == *"|"* ]] || [[ "$target" == *"&"* ]] || \
       [[ "$target" == *'$'* ]] || [[ "$target" == *";"* ]] || \
       [[ "$target" == *"<"* ]] || [[ "$target" == *">"* ]]; then
        echo "Error: Target contains invalid characters" >&2
        return 1
    fi

    if [[ ! -e "$target" ]]; then
        echo "Error: Target '$target' does not exist" >&2
        return 1
    fi

    if ! _kit_require_imagemagick; then
        return 1
    fi

    _process_single_resize_width() {
        local input="$1"
        local width="$2"
        local force="$3"
        local dry_run="$4"

        if ! _is_image_file "$input"; then
            return 0
        fi

        local filename="${input%.*}"
        local extension="${input##*.}"
        local output="${filename}-resized.${extension}"

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

        if magick "$input" -resize "$width" "$output" 2>/dev/null; then
            echo "✅ Created: $output"
            return 0
        else
            echo "Error: Resize failed for $input" >&2
            return 1
        fi
    }

    if [[ -f "$target" ]]; then
        _process_single_resize_width "$target" "$width" "$force" "$dry_run"
        return $?
    fi

    if [[ -d "$target" ]]; then
        local count=0
        local failed=0
        
        # Build find command pattern
        local find_pattern="$target/*"
        [[ "$recursive" == true ]] && find_pattern="$target/**/*"

        # Use setopt for nullglob in zsh
        setopt local_options nullglob 2>/dev/null || true

        for file in $~find_pattern; do
            [[ -f "$file" ]] || continue
            if ! _is_image_file "$file"; then
                continue
            fi
            if _process_single_resize_width "$file" "$width" "$force" "$dry_run"; then
                ((count++))
            else
                ((failed++))
            fi
        done

        echo ""
        if [[ "$dry_run" == true ]]; then
            echo "Would resize $count file(s)"
        else
            echo "Resized $count file(s)"
        fi
        [[ $failed -gt 0 ]] && echo "Failed/Skipped: $failed file(s)" >&2
        return 0
    fi
}

# Image Resize by Percentage (using Lanczos interpolation for quality - ideal for upscaling)
img-resize-percentage() {
    local force=false
    local dry_run=false
    local recursive=false
    local percentage=""
    local target=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit img-resize-percentage <percentage> <file|directory> [options]
Description: Resize image by percentage using Lanczos filter for high quality
Features: Uses Lanczos interpolation - ideal for upscaling, reduces blur
Options:
  -f, --force      Overwrite output file if it exists
  -n, --dry-run    Show what would be resized without making changes
  -r, --recursive  Process directories recursively
Examples:
  kit img-resize-percentage 200 photo.jpg    # Double size (upscale)
  kit img-resize-percentage 50 . --recursive # Half size in current dir
  kit img-resize-percentage 150 . --dry-run
Output: Creates photo-resized.jpg
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
            *)
                if [[ -z "$percentage" ]]; then
                    percentage="$1"
                elif [[ -z "$target" ]]; then
                    target="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$percentage" ]]; then
        echo "Error: Missing percentage parameter" >&2
        return 2
    fi

    if [[ -z "$target" ]]; then
        echo "Error: Missing target file or directory" >&2
        return 2
    fi

    if ! [[ "$percentage" =~ ^[0-9]+$ ]]; then
        echo "Error: Percentage must be a number (e.g., 50, 150, 200)" >&2
        return 1
    fi

    # Sanitize filename to prevent injection attacks
    if [[ "$target" == *"|"* ]] || [[ "$target" == *"&"* ]] || \
       [[ "$target" == *'$'* ]] || [[ "$target" == *";"* ]] || \
       [[ "$target" == *"<"* ]] || [[ "$target" == *">"* ]]; then
        echo "Error: Target contains invalid characters" >&2
        return 1
    fi

    if [[ ! -e "$target" ]]; then
        echo "Error: Target '$target' does not exist" >&2
        return 1
    fi

    if ! _kit_require_imagemagick; then
        return 1
    fi

    _process_single_resize_percentage() {
        local input="$1"
        local percentage="$2"
        local force="$3"
        local dry_run="$4"

        if ! _is_image_file "$input"; then
            return 0
        fi

        local filename="${input%.*}"
        local extension="${input##*.}"
        local output="${filename}-resized.${extension}"

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

        if magick "$input" -filter Lanczos -resize "$percentage%" "$output" 2>/dev/null; then
            echo "✅ Created: $output (resized to $percentage% with Lanczos filter)"
            return 0
        else
            echo "Error: Percentage resize failed for $input" >&2
            return 1
        fi
    }

    if [[ -f "$target" ]]; then
        _process_single_resize_percentage "$target" "$percentage" "$force" "$dry_run"
        return $?
    fi

    if [[ -d "$target" ]]; then
        local count=0
        local failed=0
        
        # Build find command pattern
        local find_pattern="$target/*"
        [[ "$recursive" == true ]] && find_pattern="$target/**/*"

        # Use setopt for nullglob in zsh
        setopt local_options nullglob 2>/dev/null || true

        for file in $~find_pattern; do
            [[ -f "$file" ]] || continue
            if ! _is_image_file "$file"; then
                continue
            fi
            if _process_single_resize_percentage "$file" "$percentage" "$force" "$dry_run"; then
                ((count++))
            else
                ((failed++))
            fi
        done

        echo ""
        if [[ "$dry_run" == true ]]; then
            echo "Would resize $count file(s)"
        else
            echo "Resized $count file(s)"
        fi
        [[ $failed -gt 0 ]] && echo "Failed/Skipped: $failed file(s)" >&2
        return 0
    fi
}

# Helper to check if a file is a supported image
_is_image_file() {
    local file="$1"
    local extension="${file##*.}"
    extension="${extension% }"
    extension="${extension# }"

    local -a extensions=(jpg jpeg png gif webp bmp tiff tif heic heif avif svg ico)
    for ext in "${extensions[@]}"; do
        if [[ "${extension:l}" == "${ext:l}" ]]; then
            return 0
        fi
    done
    return 1
}

# Image Optimization (strips metadata and compresses)
img-optimize() {
    local force=false
    local dry_run=false
    local recursive=false
    local target=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit img-optimize <file|directory> [options]
Description: Optimize image by stripping metadata and compressing
Effect: Strips EXIF/metadata and sets quality to 85%
Options:
  -f, --force      Overwrite output file if it exists
  -n, --dry-run    Show what would be optimized without making changes
  -r, --recursive  Process directories recursively
Examples:
  kit img-optimize photo.jpg
  kit img-optimize . --recursive --dry-run
  kit img-optimize image.png --force
Output: Creates photo-optimized.jpg
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
            *)
                if [[ -z "$target" ]]; then
                    target="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$target" ]]; then
        echo "Error: Missing target file or directory" >&2
        return 2
    fi

    # Sanitize filename to prevent injection attacks
    # Note: Using fixed character class - backslash-escape inside [] has inconsistent behavior
    if [[ "$target" == *"|"* ]] || [[ "$target" == *"&"* ]] || \
       [[ "$target" == *'$'* ]] || [[ "$target" == *";"* ]] || \
       [[ "$target" == *"<"* ]] || [[ "$target" == *">"* ]]; then
        echo "Error: Target contains invalid characters" >&2
        return 1
    fi

    if [[ ! -e "$target" ]]; then
        echo "Error: Target '$target' does not exist" >&2
        return 1
    fi

    if ! _kit_require_imagemagick; then
        return 1
    fi

    _process_single_optimize() {
        local input="$1"
        local force="$2"
        local dry_run="$3"

        if ! _is_image_file "$input"; then
            return 0
        fi

        local filename="${input%.*}"
        local extension="${input##*.}"
        local output="${filename}-optimized.${extension}"

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

        if magick "$input" -strip -quality 85 "$output" 2>/dev/null; then
            echo "✅ Created: $output"
            return 0
        else
            echo "Error: Optimization failed for $input" >&2
            return 1
        fi
    }

    if [[ -f "$target" ]]; then
        _process_single_optimize "$target" "$force" "$dry_run"
        return $?
    fi

    if [[ -d "$target" ]]; then
        local count=0
        local failed=0
        
        # Build find command pattern
        local find_pattern="$target/*"
        [[ "$recursive" == true ]] && find_pattern="$target/**/*"

        # Use setopt for nullglob in zsh
        setopt local_options nullglob 2>/dev/null || true

        for file in $~find_pattern; do
            [[ -f "$file" ]] || continue
            if ! _is_image_file "$file"; then
                continue
            fi
            if _process_single_optimize "$file" "$force" "$dry_run"; then
                ((count++))
            else
                ((failed++))
            fi
        done

        echo ""
        if [[ "$dry_run" == true ]]; then
            echo "Would optimize $count file(s)"
        else
            echo "Optimized $count file(s)"
        fi
        [[ $failed -gt 0 ]] && echo "Failed/Skipped: $failed file(s)" >&2
        return 0
    fi
}

# Unified Image Format Conversion
img-convert() {
    local target="."
    local from_format=""
    local to_format=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit img-convert <from_format> <to_format> [directory]
Description: Convert all images of one format to another format
Supported formats: png, jpg, jpeg, webp, heic, avif, bmp, tiff, gif, pdf
Examples:
  kit img-convert png jpg         # Convert all PNG to JPG in current dir
  kit img-convert heic webp ./old # Convert all HEIC to WebP in ./old
  kit img-convert jpg png .       # Convert all JPG to PNG in current dir
Output: Creates <directory>/converted/ directory with converted files
EOF
                return 0
                ;;
            *)
                if [[ -z "$from_format" ]]; then
                    from_format="$1"
                elif [[ -z "$to_format" ]]; then
                    to_format="$1"
                elif [[ -z "$target" || "$target" == "." ]]; then
                    target="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$from_format" || -z "$to_format" ]]; then
        echo "Error: Missing format parameters" >&2
        return 2
    fi

    if [[ ! -d "$target" ]]; then
        echo "Error: Directory '$target' does not exist" >&2
        return 1
    fi

    if ! _kit_require_imagemagick; then
        return 1
    fi

    # Find all matching files (case-insensitive)
    setopt local_options nullglob 2>/dev/null || true
    local -a input_files=()
    
    # Check for formats in target directory
    for file in "$target"/*.{"$from_format","${from_format:u}","${from_format:l}"}; do
        [[ -f "$file" ]] && input_files+=("$file")
    done

    if [[ ${#input_files[@]} -eq 0 ]]; then
        echo "Error: No .$from_format files found in '$target'" >&2
        return 1
    fi

    echo "Converting ${#input_files[@]} file(s) from $from_format to $to_format in '$target'..."

    # Create output directory relative to target
    local out_dir="${target}/converted"
    mkdir -p "$out_dir" || {
        echo "Error: Cannot create '$out_dir' directory" >&2
        return 1
    }

    # Convert files
    if magick mogrify -path "$out_dir" -format "$to_format" -quality 90 -auto-orient "${input_files[@]}" 2>/dev/null; then
        local count=$(ls -1 "$out_dir"/*."$to_format" 2>/dev/null | wc -l | tr -d ' ')
        echo "✅ Converted $count file(s) to $to_format in $out_dir"
        return 0
    else
        echo "Error: Conversion failed" >&2
        return 1
    fi
}

# Optimize images to WebP format with maximum quality and compression
img-optimize-to-webp() {
    local target="."

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit img-optimize-to-webp [directory]
Description: Convert all supported images (PNG, JPG, HEIC) to optimized WebP format
Features: Maximum quality (90), best compression (method=6, pass=10), sharp-yuv enabled
Supported: PNG, JPG, JPEG, HEIC
Example: 
  kit img-optimize-to-webp        # Current directory
  kit img-optimize-to-webp ./pics # Process ./pics
Output: Creates <directory>/optimized/ directory with WebP files
EOF
                return 0
                ;;
            *)
                if [[ -z "$target" || "$target" == "." ]]; then
                    target="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ ! -d "$target" ]]; then
        echo "Error: Directory '$target' does not exist" >&2
        return 1
    fi

    if ! _kit_require_imagemagick; then
        return 1
    fi

    # Find all supported image files
    setopt local_options nullglob 2>/dev/null || true
    local -a input_files=()
    for file in "$target"/*.{png,jpg,jpeg,HEIC,heic,PNG,JPG,JPEG}; do
        [[ -f "$file" ]] && input_files+=("$file")
    done

    if [[ ${#input_files[@]} -eq 0 ]]; then
        echo "Error: No supported image files found in '$target' (PNG, JPG, HEIC)" >&2
        return 1
    fi

    echo "Optimizing ${#input_files[@]} image(s) to WebP in '$target'..."

    # Create output directory relative to target
    local out_dir="${target}/optimized"
    mkdir -p "$out_dir" || {
        echo "Error: Cannot create '$out_dir' directory" >&2
        return 1
    }

    # Optimize to WebP with maximum quality settings
    local WEBP_METHOD=6  # Compression method: 0=fast, 6=best compression (slower)
    local WEBP_PASS=10   # Number of compression passes: higher = better compression (slower)

    if magick mogrify -path "$out_dir" -format webp -quality 90 -define webp:method=$WEBP_METHOD -define webp:pass=$WEBP_PASS -define webp:use-sharp-yuv=1 "${input_files[@]}" 2>/dev/null; then
        local count=$(ls -1 "$out_dir"/*.webp 2>/dev/null | wc -l | tr -d ' ')
        echo "✅ Optimized $count file(s) to WebP in $out_dir"
        return 0
    else
        echo "Error: Optimization failed" >&2
        return 1
    fi
}

# ============================================================================
# ImageMagick Advanced Resize Functions (Safety-First Series)
# ============================================================================

# General image resize preserving aspect ratio
img-resize() {
    local force=false
    local dry_run=false
    local recursive=false
    local size=""
    local target=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit img-resize <width>x<height> <file|directory> [options]
Description: Resize image preserving aspect ratio, output has -resized suffix
Options:
  -f, --force      Overwrite output file if it exists
  -n, --dry-run    Show what would be resized without making changes
  -r, --recursive  Process directories recursively
Examples:
  kit img-resize 800x600 photo.jpg        # Fit within 800x600
  kit img-resize 1024 . --recursive       # Width 1024 in current dir
  kit img-resize 1920x1080 . --dry-run
Output: Creates photo-resized.jpg
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
            *)
                if [[ -z "$size" ]]; then
                    size="$1"
                elif [[ -z "$target" ]]; then
                    target="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$size" ]]; then
        echo "Error: Missing size parameter" >&2
        return 2
    fi

    if [[ -z "$target" ]]; then
        echo "Error: Missing target file or directory" >&2
        return 2
    fi

    # Sanitize filename to prevent injection attacks
    if [[ "$target" == *"|"* ]] || [[ "$target" == *"&"* ]] || \
       [[ "$target" == *'$'* ]] || [[ "$target" == *";"* ]] || \
       [[ "$target" == *"<"* ]] || [[ "$target" == *">"* ]]; then
        echo "Error: Target contains invalid characters" >&2
        return 1
    fi

    if [[ ! -e "$target" ]]; then
        echo "Error: Target '$target' does not exist" >&2
        return 1
    fi

    if ! _kit_require_imagemagick; then
        return 1
    fi

    _process_single_resize() {
        local input="$1"
        local size="$2"
        local force="$3"
        local dry_run="$4"

        if ! _is_image_file "$input"; then
            return 0
        fi

        local filename="${input%.*}"
        local extension="${input##*.}"
        local output="${filename}-resized.${extension}"

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

        if magick "$input" -resize "$size" "$output" 2>/dev/null; then
            echo "✅ Created: $output"
            return 0
        else
            echo "Error: Resize failed for $input" >&2
            return 1
        fi
    }

    if [[ -f "$target" ]]; then
        _process_single_resize "$target" "$size" "$force" "$dry_run"
        return $?
    fi

    if [[ -d "$target" ]]; then
        local count=0
        local failed=0
        
        # Build find command pattern
        local find_pattern="$target/*"
        [[ "$recursive" == true ]] && find_pattern="$target/**/*"

        # Use setopt for nullglob in zsh
        setopt local_options nullglob 2>/dev/null || true

        for file in $~find_pattern; do
            [[ -f "$file" ]] || continue
            if ! _is_image_file "$file"; then
                continue
            fi
            if _process_single_resize "$file" "$size" "$force" "$dry_run"; then
                ((count++))
            else
                ((failed++))
            fi
        done

        echo ""
        if [[ "$dry_run" == true ]]; then
            echo "Would resize $count file(s)"
        else
            echo "Resized $count file(s)"
        fi
        [[ $failed -gt 0 ]] && echo "Failed/Skipped: $failed file(s)" >&2
        return 0
    fi
}

# Fast thumbnail generation with profile stripping
img-thumbnail() {
    if [[ "$1" == "-h" || -z "$1" || -z "$2" ]]; then
        cat << EOF
Usage: kit img-thumbnail <width>x<height> <file>
Description: Fast thumbnail generation, strips profiles, output has -resized suffix
Features: Optimized for speed, profile stripping, great for batch operations
Examples:
  kit img-thumbnail 200x200 photo.jpg
  kit img-thumbnail 300x300 large_image.png
Output: Creates photo-resized.jpg (thumbnail)
EOF
        return 0
    fi

    local size="$1"
    local input="$2"
    local filename="${input%.*}"
    local extension="${input##*.}"
    local output="${filename}-resized.${extension}"

    if [[ ! -f "$input" ]]; then
        echo "Error: Input file '$input' does not exist" >&2
        return 1
    fi

    if ! _kit_require_imagemagick; then
        return 1
    fi

    # Check if output file exists
    if [[ -f "$output" ]]; then
        echo "Error: Output file '$output' already exists. Please remove it or choose a different location." >&2
        return 1
    fi

    if magick "$input" -thumbnail "$size" -strip "$output" 2>/dev/null; then
        echo "✅ Created thumbnail: $output"
        return 0
    else
        echo "Error: Thumbnail generation failed for $input" >&2
        return 1
    fi
}

# Force exact dimensions (ignore aspect ratio)
img-resize-exact() {
    if [[ "$1" == "-h" || -z "$1" || -z "$2" ]]; then
        cat << EOF
Usage: kit img-resize-exact <width>x<height> <file>
Description: Force exact dimensions, ignores aspect ratio, output has -resized suffix
⚠️  WARNING: This will distort the image to exact size
Examples:
  kit img-resize-exact 800x600 photo.jpg      # Force 800x600 (may distort)
  kit img-resize-exact 1024x768 image.png
Output: Creates photo-resized.jpg
EOF
        return 0
    fi

    local size="$1"
    local input="$2"
    local filename="${input%.*}"
    local extension="${input##*.}"
    local output="${filename}-resized.${extension}"

    if [[ ! -f "$input" ]]; then
        echo "Error: Input file '$input' does not exist" >&2
        return 1
    fi

    if ! _kit_require_imagemagick; then
        return 1
    fi

    # Check if output file exists
    if [[ -f "$output" ]]; then
        echo "Error: Output file '$output' already exists. Please remove it or choose a different location." >&2
        return 1
    fi

    if magick "$input" -resize "${size}!" "$output" 2>/dev/null; then
        echo "✅ Created: $output (forced to exact dimensions)"
        return 0
    else
        echo "Error: Exact resize failed for $input" >&2
        return 1
    fi
}

# Resize to fill space and crop excess
img-resize-fill() {
    if [[ "$1" == "-h" || -z "$1" || -z "$2" ]]; then
        cat << EOF
Usage: kit img-resize-fill <width>x<height> <file>
Description: Resize to fill area, crop excess, centered, output has -resized suffix
Features: Fills entire space, crops excess intelligently, center-aligned
Examples:
  kit img-resize-fill 800x600 photo.jpg
  kit img-resize-fill 1024x1024 image.png
Output: Creates photo-resized.jpg (fills entire 800x600 space)
EOF
        return 0
    fi

    local size="$1"
    local input="$2"
    local filename="${input%.*}"
    local extension="${input##*.}"
    local output="${filename}-resized.${extension}"

    if [[ ! -f "$input" ]]; then
        echo "Error: Input file '$input' does not exist" >&2
        return 1
    fi

    if ! _kit_require_imagemagick; then
        return 1
    fi

    # Check if output file exists
    if [[ -f "$output" ]]; then
        echo "Error: Output file '$output' already exists. Please remove it or choose a different location." >&2
        return 1
    fi

    if magick "$input" -resize "${size}^" -gravity center -extent "$size" "$output" 2>/dev/null; then
        echo "✅ Created: $output (filled and cropped to $size)"
        return 0
    else
        echo "Error: Fill resize failed for $input" >&2
        return 1
    fi
}

# Quality resize without blurring (adaptive/mesh interpolation)
img-adaptive-resize() {
    if [[ "$1" == "-h" || -z "$1" || -z "$2" ]]; then
        cat << EOF
Usage: kit img-adaptive-resize <width>x<height> <file>
Description: Quality resize using mesh interpolation, minimal blur, output has -resized suffix
Best for: Small size adjustments, magnification, sharp color changes
Examples:
  kit img-adaptive-resize 800x600 photo.jpg
  kit img-adaptive-resize 1.5x image.png        # 150% magnification
Output: Creates photo-resized.jpg (higher quality than standard resize)
EOF
        return 0
    fi

    local size="$1"
    local input="$2"
    local filename="${input%.*}"
    local extension="${input##*.}"
    local output="${filename}-resized.${extension}"

    if [[ ! -f "$input" ]]; then
        echo "Error: Input file '$input' does not exist" >&2
        return 1
    fi

    if ! _kit_require_imagemagick; then
        return 1
    fi

    # Check if output file exists
    if [[ -f "$output" ]]; then
        echo "Error: Output file '$output' already exists. Please remove it or choose a different location." >&2
        return 1
    fi

    if magick "$input" -adaptive-resize "$size" "$output" 2>/dev/null; then
        echo "✅ Created: $output (adaptive resize - high quality)"
        return 0
    else
        echo "Error: Adaptive resize failed for $input" >&2
        return 1
    fi
}

# Batch resize multiple images (sequential, safety-first)
img-batch-resize() {
    if [[ "$1" == "-h" || -z "$1" || -z "$2" ]]; then
        cat << EOF
Usage: kit img-batch-resize <width>x<height> <file1> [file2] [file3] ...
Description: Batch resize multiple images sequentially, all get -resized suffix
Features: Safety-first (sequential), progress feedback, error handling
Examples:
  kit img-batch-resize 800x600 *.jpg
  kit img-batch-resize 1024x1024 photo1.jpg photo2.jpg photo3.png
Output: Creates photo1-resized.jpg, photo2-resized.jpg, photo3-resized.png
EOF
        return 0
    fi

    local size="$1"
    shift
    local files=("$@")
    local success_count=0
    local fail_count=0

    if ! _kit_require_imagemagick; then
        return 1
    fi

    if [[ ${#files[@]} -eq 0 ]]; then
        echo "Error: No files specified" >&2
        return 1
    fi

    echo "Processing ${#files[@]} file(s)..."

    for input in "${files[@]}"; do
        if [[ ! -f "$input" ]]; then
            echo "⚠️  Skipping: '$input' (not found)"
            ((fail_count++))
            continue
        fi

        local filename="${input%.*}"
        local extension="${input##*.}"
        local output="${filename}-resized.${extension}"

        # Check if output file exists
        if [[ -f "$output" ]]; then
            echo "⚠️  Skipping: '$input' (output '$output' already exists)"
            ((fail_count++))
            continue
        fi

        if magick "$input" -resize "$size" "$output" 2>/dev/null; then
            echo "✅ $input → $output"
            ((success_count++))
        else
            echo "❌ Failed: $input"
            ((fail_count++))
        fi
    done

    echo ""
    echo "Summary: $success_count succeeded, $fail_count failed"
    return 0
}

# Only shrink, never enlarge
img-resize-shrink-only() {
    if [[ "$1" == "-h" || -z "$1" || -z "$2" ]]; then
        cat << EOF
Usage: kit img-resize-shrink-only <width>x<height> <file>
Description: Only shrink images, never enlarge, output has -resized suffix
Features: Safe for thumbnails, ignores resize if already smaller
Examples:
  kit img-resize-shrink-only 800x600 photo.jpg
  kit img-resize-shrink-only 1024 large_image.png
Output: Creates photo-resized.jpg (only if original is larger)
EOF
        return 0
    fi

    local size="$1"
    local input="$2"
    local filename="${input%.*}"
    local extension="${input##*.}"
    local output="${filename}-resized.${extension}"

    if [[ ! -f "$input" ]]; then
        echo "Error: Input file '$input' does not exist" >&2
        return 1
    fi

    if ! _kit_require_imagemagick; then
        return 1
    fi

    # Check if output file exists
    if [[ -f "$output" ]]; then
        echo "Error: Output file '$output' already exists. Please remove it or choose a different location." >&2
        return 1
    fi

    if magick "$input" -resize "${size}>" "$output" 2>/dev/null; then
        echo "✅ Created: $output (shrink-only resize)"
        return 0
    else
        echo "Error: Shrink-only resize failed for $input" >&2
        return 1
    fi
}

# Resize with colorspace correction for better quality
img-resize-colorspace() {
    if [[ "$1" == "-h" || -z "$1" || -z "$2" || -z "$3" ]]; then
        cat << EOF
Usage: kit img-resize-colorspace <width>x<height> <file> [-m rgb|lab|luv]
Description: Resize with colorspace correction for better quality, output has -resized suffix
Colorspace options:
  rgb - Linear RGB (mathematical accuracy, can have color clipping)
  lab - LAB perceptual (separates intensity from color, avoids clipping) ⭐ RECOMMENDED
  luv - LUV perceptual (similar to LAB, perceptually uniform)
Examples:
  kit img-resize-colorspace 800x600 photo.jpg -m lab    # LAB (recommended)
  kit img-resize-colorspace 1024 image.png -m rgb       # Linear RGB
  kit img-resize-colorspace 500x500 earth.tif -m luv    # LUV colorspace
Output: Creates photo-resized.jpg (better color accuracy)
EOF
        return 0
    fi

    local size="$1"
    local input="$2"
    local colorspace="lab"  # Default to LAB (best practice)

    # Parse optional colorspace argument
    if [[ "$3" == "-m" && -n "$4" ]]; then
        colorspace="$4"
    fi

    # Validate colorspace
    if [[ ! "$colorspace" =~ ^(rgb|lab|luv)$ ]]; then
        echo "Error: Invalid colorspace '$colorspace'. Use: rgb, lab, or luv" >&2
        return 1
    fi

    local filename="${input%.*}"
    local extension="${input##*.}"
    local output="${filename}-resized.${extension}"

    if [[ ! -f "$input" ]]; then
        echo "Error: Input file '$input' does not exist" >&2
        return 1
    fi

    if ! _kit_require_imagemagick; then
        return 1
    fi

    # Check if output file exists
    if [[ -f "$output" ]]; then
        echo "Error: Output file '$output' already exists. Please remove it or choose a different location." >&2
        return 1
    fi

    echo "Resizing with $colorspace colorspace correction..."

    if magick "$input" \
        -colorspace "$colorspace" \
        -filter Lanczos \
        -resize "$size" \
        -colorspace sRGB \
        "$output" 2>/dev/null; then
        echo "✅ Created: $output (resized with $colorspace colorspace)"
        return 0
    else
        echo "Error: Colorspace resize failed for $input" >&2
        return 1
    fi
}