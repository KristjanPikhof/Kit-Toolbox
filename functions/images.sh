# images.sh - Image manipulation utilities using ImageMagick
# Category: Image Processing
# Description: ImageMagick-based image manipulation and optimization utilities
# Dependencies: imagemagick
# Functions: img-resize-width, img-resize-percentage, img-optimize, img-convert, img-optimize-to-webp, img-resize, img-thumbnail, img-resize-exact, img-resize-fill, img-adaptive-resize, img-batch-resize, img-resize-shrink-only, img-resize-colorspace

# Image Resize by Width (height auto-calculated to preserve aspect ratio)
img-resize-width() {
    if [[ "$1" == "-h" || -z "$1" ]]; then
        cat << EOF
Usage: kit img-resize-width <width> <file>
Description: Simple resize by width only, height auto-calculated, preserves aspect ratio
Examples:
  kit img-resize-width 800 photo.jpg
  kit img-resize-width 1920 landscape.png
Output: Creates photo-resized.jpg
EOF
        return 0
    fi

    if [[ -z "$2" ]]; then
        echo "Error: Missing input file" >&2
        return 2
    fi

    # Sanitize filename to prevent injection attacks
    if [[ "$2" =~ [\|\&\$\`\'\;\<\>] ]]; then
        echo "Error: Filename contains invalid characters" >&2
        return 1
    fi

    if [[ ! -f "$2" ]]; then
        echo "Error: Input file '$2' does not exist" >&2
        return 1
    fi

    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
        return 1
    fi

    local input="$2"
    local filename="${input%.*}"
    local extension="${input##*.}"
    local output="${filename}-resized.${extension}"

    # Check if output file exists
    if [[ -f "$output" ]]; then
        echo "Error: Output file '$output' already exists. Please remove it or choose a different location." >&2
        return 1
    fi

    if magick "$input" -resize "$1" "$output" 2>/dev/null; then
        echo "✅ Created: $output"
        return 0
    else
        echo "Error: Resize failed for $input" >&2
        return 1
    fi
}

# Image Resize by Percentage (using Lanczos interpolation for quality - ideal for upscaling)
img-resize-percentage() {
    if [[ "$1" == "-h" || -z "$1" ]]; then
        cat << EOF
Usage: kit img-resize-percentage <percentage> <file>
Description: Resize image by percentage using Lanczos filter for high quality
Features: Uses Lanczos interpolation - ideal for upscaling, reduces blur
Examples:
  kit img-resize-percentage 200 photo.jpg    # Double size (upscale)
  kit img-resize-percentage 50 large.png     # Reduce to 50%
  kit img-resize-percentage 150 image.jpg    # Upscale to 150%
Output: Creates photo-resized.jpg
EOF
        return 0
    fi

    if [[ -z "$2" ]]; then
        echo "Error: Missing input file" >&2
        return 2
    fi

    # Sanitize filename to prevent injection attacks
    if [[ "$2" =~ [\|\&\$\`\'\;\<\>] ]]; then
        echo "Error: Filename contains invalid characters" >&2
        return 1
    fi

    if [[ ! -f "$2" ]]; then
        echo "Error: Input file '$2' does not exist" >&2
        return 1
    fi

    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
        return 1
    fi

    if ! [[ "$1" =~ ^[0-9]+$ ]]; then
        echo "Error: Percentage must be a number (e.g., 50, 150, 200)" >&2
        return 1
    fi

    local input="$2"
    local filename="${input%.*}"
    local extension="${input##*.}"
    local output="${filename}-resized.${extension}"

    # Check if output file exists
    if [[ -f "$output" ]]; then
        echo "Error: Output file '$output' already exists. Please remove it or choose a different location." >&2
        return 1
    fi

    if magick "$input" -filter Lanczos -resize "$1%" "$output" 2>/dev/null; then
        echo "✅ Created: $output (resized to $1% with Lanczos filter)"
        return 0
    else
        echo "Error: Percentage resize failed for $input" >&2
        return 1
    fi
}

# Image Optimization (strips metadata and compresses)
img-optimize() {
    if [[ "$1" == "-h" || -z "$1" ]]; then
        cat << EOF
Usage: kit img-optimize <file>
Description: Optimize image by stripping metadata and compressing
Effect: Strips EXIF/metadata and sets quality to 85%
Examples:
  kit img-optimize photo.jpg
  kit img-optimize image.png
Output: Creates photo-optimized.jpg
EOF
        return 0
    fi

    # Sanitize filename to prevent injection attacks
    if [[ "$1" =~ [\|\&\$\`\'\;\<\>] ]]; then
        echo "Error: Filename contains invalid characters" >&2
        return 1
    fi

    if [[ ! -f "$1" ]]; then
        echo "Error: Input file '$1' does not exist" >&2
        return 1
    fi

    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
        return 1
    fi

    local input="$1"
    local filename="${input%.*}"
    local extension="${input##*.}"
    local output="${filename}-optimized.${extension}"

    # Check if output file exists
    if [[ -f "$output" ]]; then
        echo "Error: Output file '$output' already exists. Please remove it or choose a different location." >&2
        return 1
    fi

    if magick "$input" -strip -quality 85 "$output" 2>/dev/null; then
        echo "✅ Created: $output"
        return 0
    else
        echo "Error: Optimization failed for $input" >&2
        return 1
    fi
}

# Unified Image Format Conversion
img-convert() {
    if [[ "$1" == "-h" || "$1" == "--help" || $# -lt 2 ]]; then
        cat << EOF
Usage: kit img-convert <from_format> <to_format>
Description: Convert all images of one format to another format in current directory
Supported formats: png, jpg, jpeg, webp, heic, avif, bmp, tiff, gif, pdf
Examples:
  kit img-convert png jpg         # Convert all PNG to JPG
  kit img-convert heic webp       # Convert all HEIC to WebP
  kit img-convert jpg png         # Convert all JPG to PNG
Output: Creates converted/ directory with converted files
EOF
        return 0
    fi

    setopt local_options nullglob 2>/dev/null || true

    local from_format="$1"
    local to_format="$2"
    local valid_formats=(png jpg jpeg webp heic avif bmp tiff gif pdf PNG JPG JPEG HEIC)

    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
        return 1
    fi

    # Find all matching files (case-insensitive)
    local input_files=()
    for ext in "$from_format" "${from_format^^}" "${from_format,,}"; do
        for file in *.$ext; do
            [[ -f "$file" ]] && input_files+=("$file")
        done
    done

    if [[ ${#input_files[@]} -eq 0 ]]; then
        echo "Error: No .$from_format files found in current directory" >&2
        return 1
    fi

    echo "Converting ${#input_files[@]} file(s) from $from_format to $to_format..."

    # Create output directory
    mkdir -p converted || {
        echo "Error: Cannot create 'converted' directory" >&2
        return 1
    }

    # Convert files
    if magick mogrify -path converted -format "$to_format" -quality 90 -auto-orient "${input_files[@]}" 2>/dev/null; then
        local count=$(ls -1 converted/*.$to_format 2>/dev/null | wc -l | tr -d ' ')
        echo "✅ Converted $count file(s) to $to_format in ./converted"
        return 0
    else
        echo "Error: Conversion failed" >&2
        return 1
    fi
}

# Optimize images to WebP format with maximum quality and compression
img-optimize-to-webp() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit img-optimize-to-webp
Description: Convert all supported images (PNG, JPG, HEIC) to optimized WebP format
Features: Maximum quality (90), best compression (method=6, pass=10), sharp-yuv enabled
Supported: PNG, JPG, JPEG, HEIC
Example: kit img-optimize-to-webp
Output: Creates optimized/ directory with WebP files
EOF
        return 0
    fi

    setopt local_options nullglob 2>/dev/null || true

    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
        return 1
    fi

    # Find all supported image files
    local input_files=()
    for ext in png jpg jpeg HEIC heic PNG JPG JPEG; do
        for file in *.$ext; do
            [[ -f "$file" ]] && input_files+=("$file")
        done
    done

    if [[ ${#input_files[@]} -eq 0 ]]; then
        echo "Error: No supported image files found (PNG, JPG, HEIC)" >&2
        return 1
    fi

    echo "Optimizing ${#input_files[@]} image(s) to WebP with maximum quality..."

    # Create output directory
    mkdir -p optimized || {
        echo "Error: Cannot create 'optimized' directory" >&2
        return 1
    }

    # Optimize to WebP with maximum quality settings
    local WEBP_METHOD=6  # Compression method: 0=fast, 6=best compression (slower)
    local WEBP_PASS=10   # Number of compression passes: higher = better compression (slower)

    if magick mogrify -path optimized -format webp -quality 90 -define webp:method=$WEBP_METHOD -define webp:pass=$WEBP_PASS -define webp:use-sharp-yuv=1 "${input_files[@]}" 2>/dev/null; then
        local count=$(ls -1 optimized/*.webp 2>/dev/null | wc -l | tr -d ' ')
        echo "✅ Optimized $count file(s) to WebP in ./optimized"
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
    if [[ "$1" == "-h" || -z "$1" || -z "$2" ]]; then
        cat << EOF
Usage: kit img-resize <width>x<height> <file>
Description: Resize image preserving aspect ratio, output has -resized suffix
Examples:
  kit img-resize 800x600 photo.jpg        # Fit within 800x600
  kit img-resize 1024 landscape.png       # Width 1024, height auto
  kit img-resize 1920x1080 video_frame.jpg
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

    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
        return 1
    fi

    # Check if output file exists
    if [[ -f "$output" ]]; then
        echo "Error: Output file '$output' already exists. Please remove it or choose a different location." >&2
        return 1
    fi

    if magick "$input" -resize "$size" "$output" 2>/dev/null; then
        echo "✅ Created: $output"
        return 0
    else
        echo "Error: Resize failed for $input" >&2
        return 1
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

    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
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

    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
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

    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
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

    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
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

    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
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

    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
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

    if ! command -v magick &> /dev/null; then
        echo "Error: ImageMagick not installed. Install with: brew install imagemagick" >&2
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