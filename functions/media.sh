# media.sh - Media processing utilities using yt-dlp and ffmpeg
# Category: Media Processing
# Description: Video and audio processing tools using yt-dlp and ffmpeg
# Dependencies: yt-dlp, ffmpeg
# Functions: yt-download, remove-audio, convert-to-mp3, compress-video

yt-download() {
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit yt-download <mode> <url> [quality]
Description: Download YouTube videos or audio using yt-dlp
Modes: mp3 (audio only), mp4 (video)
Quality: For mp3: 0 (best) to 9 (worst), default 0
         For mp4: yt-dlp format selector, default "bv*+ba/b"
Examples:
  kit yt-download mp3 "https://youtube.com/watch?v=..." 0
  kit yt-download mp4 "https://youtube.com/watch?v=..."
EOF
        return 0
    fi

    # Input validation
    if [[ $# -lt 2 ]]; then
        echo "Error: Missing required arguments. Use -h for help." >&2
        return 2
    fi

    local mode="$1"
    local url="$2"
    local quality="$3"
    local opts=(--no-playlist --embed-metadata --embed-thumbnail)

    # Dependency check
    if ! command -v yt-dlp &> /dev/null; then
        echo "Error: yt-dlp not installed. Install with: brew install yt-dlp" >&2
        return 1
    fi

    # Mode validation
    case "$mode" in
        mp3)
            if ! yt-dlp "${opts[@]}" -x --audio-format mp3 --audio-quality "${quality:-0}" "$url" 2>/dev/null; then
                echo "Error: Failed to download audio from URL: $url" >&2
                return 1
            fi
            ;;
        mp4)
            if ! yt-dlp "${opts[@]}" -f "${quality:-bv*+ba/b}" "$url" 2>/dev/null; then
                echo "Error: Failed to download video from URL: $url" >&2
                return 1
            fi
            ;;
        *)
            echo "Error: Invalid mode '$mode'. Use 'mp3' or 'mp4'." >&2
            return 2
            ;;
    esac

    echo "Download completed successfully"
}

remove-audio() {
    local force=false
    local input=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit remove-audio <input_video_file> [options]
Description: Removes audio track from video file and optimizes for smaller size
Options:
  -f, --force    Overwrite output file if it exists
Example: kit remove-audio video.mp4
Output: Creates video_noaudio.mp4
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
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
        echo "Error: Missing input video file" >&2
        return 2
    fi

    if [[ ! -f "$input" ]]; then
        echo "Error: Input file '$input' does not exist" >&2
        return 1
    fi

    # Dependency check
    if ! command -v ffmpeg &> /dev/null; then
        echo "Error: ffmpeg not installed. Install with: brew install ffmpeg" >&2
        return 1
    fi

    local output="${input%.*}_noaudio.mp4"

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

    # Process video
    if ! ffmpeg -i "$input" -c:v libx264 -crf 23 -preset fast -an -movflags +faststart "$output" 2>/dev/null; then
        echo "Error: Failed to process video file '$input'" >&2
        return 1
    fi

    echo "Created: $output"
}

convert-to-mp3() {
    local force=false
    local input=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit convert-to-mp3 <input_media_file> [options]
Description: Extract audio from video file and convert to MP3 format (320kbps)
Options:
  -f, --force    Overwrite output file if it exists
Example: kit convert-to-mp3 video.mkv
Output: Creates video.mp3
EOF
                return 0
                ;;
            -f|--force)
                force=true
                shift
                ;;
            *)
                if [[ -z "$input" ]]; then
                    input="$1"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$input" ]]; then
        echo "Error: Missing input media file" >&2
        return 2
    fi

    if [[ ! -f "$input" ]]; then
        echo "Error: Input file '$input' does not exist" >&2
        return 1
    fi

    # Dependency check
    if ! command -v ffmpeg &> /dev/null; then
        echo "Error: ffmpeg not installed. Install with: brew install ffmpeg" >&2
        return 1
    fi

    local filename="${input%.*}"
    local output="${filename}.mp3"

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

    # Convert to MP3
    if ! ffmpeg -i "$input" -vn -acodec libmp3lame -ab 320k "$output" 2>/dev/null; then
        echo "Error: Failed to convert '$input' to MP3" >&2
        return 1
    fi

    echo "Created: $output"
}

compress-video() {
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit compress-video <input_video> [options]
Description: Compress video files to reduce size for uploads
Options:
  -o, --output FILE    Output file (default: input_compressed.mp4)
  -c, --crf NUM        Quality level 18-28 (default: 23, lower=better)
  -p, --preset PRESET  Encoding speed (default: slow)
                       Options: ultrafast, superfast, veryfast, faster,
                                fast, medium, slow, slower, veryslow
  -w, --width NUM      Scale width (default: 1280, -1 for no scaling)
  -b, --bitrate NUM    Audio bitrate in k (default: 128)
  -v, --verbose        Show ffmpeg output
Examples:
  kit compress-video video.mp4
  kit compress-video video.mp4 -c 28 -o small.mp4
  kit compress-video video.mp4 --width 1920 --preset medium
EOF
        return 0
    fi

    local input=""
    local output=""
    local crf=23
    local preset="slow"
    local width=1280
    local bitrate="128k"
    local verbose=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)
                output="$2"
                shift 2
                ;;
            -c|--crf)
                crf="$2"
                shift 2
                ;;
            -p|--preset)
                preset="$2"
                shift 2
                ;;
            -w|--width)
                width="$2"
                shift 2
                ;;
            -b|--bitrate)
                bitrate="${2}k"
                shift 2
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                return 2
                ;;
            *)
                input="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$input" ]]; then
        echo "Error: Missing input video file" >&2
        return 2
    fi

    if [[ ! -f "$input" ]]; then
        echo "Error: Input file '$input' does not exist" >&2
        return 1
    fi

    if ! command -v ffmpeg &> /dev/null; then
        echo "Error: ffmpeg not installed. Install with: brew install ffmpeg" >&2
        return 1
    fi

    if [[ -z "$output" ]]; then
        output="${input%.*}_compressed.mp4"
    fi

    # Validate CRF value (must be numeric, 0-51)
    if ! [[ "$crf" =~ ^[0-9]+$ ]] || [[ "$crf" -lt 0 ]] || [[ "$crf" -gt 51 ]]; then
        echo "Error: Invalid CRF value '$crf'. Must be between 0 and 51." >&2
        return 2
    fi

    # Validate preset (must be one of the allowed values)
    local valid_presets=(ultrafast superfast veryfast faster fast medium slow slower veryslow)
    local preset_valid=false
    for p in "${valid_presets[@]}"; do
        if [[ "$preset" == "$p" ]]; then
            preset_valid=true
            break
        fi
    done
    if [[ "$preset_valid" == false ]]; then
        echo "Error: Invalid preset '$preset'. Must be one of: ${valid_presets[*]}" >&2
        return 2
    fi

    # Validate width (must be -1 or positive integer)
    if [[ "$width" != "-1" ]] && ! [[ "$width" =~ ^[0-9]+$ ]]; then
        echo "Error: Invalid width '$width'. Must be -1 or a positive integer." >&2
        return 2
    fi

    # Build ffmpeg command as array for safe execution
    local -a ffmpeg_cmd=(ffmpeg -i "$input" -c:v libx264 -crf "$crf" -preset "$preset" -c:a aac -b:a "$bitrate")

    if [[ "$width" != "-1" ]]; then
        ffmpeg_cmd+=(-vf "scale=$width:-1")
    fi

    ffmpeg_cmd+=(-movflags +faststart "$output")

    # Execute with appropriate output redirection
    local ffmpeg_output="/dev/null"
    [[ "$verbose" == true ]] && ffmpeg_output="/dev/stderr"

    if ! "${ffmpeg_cmd[@]}" 2>"$ffmpeg_output"; then
        echo "Error: Failed to compress video file '$input'" >&2
        return 1
    fi

    local input_size=$(du -h "$input" | cut -f1)
    local output_size=$(du -h "$output" | cut -f1)

    echo "Compressed: $output ($input_size → $output_size)"
    return 0
}

