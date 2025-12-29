# media.sh - Media processing utilities using yt-dlp and ffmpeg
# Category: Media Processing
# Description: Video and audio processing tools using yt-dlp and ffmpeg
# Dependencies: yt-dlp, ffmpeg
# Functions: yt-download, removeaudio, convert-to-mp3

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

removeaudio() {
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit removeaudio <input_video_file>
Description: Removes audio track from video file and optimizes for smaller size
Example: kit removeaudio video.mp4
Output: Creates video_noaudio.mp4
EOF
        return 0
    fi

    # Input validation
    if [[ -z "$1" ]]; then
        echo "Error: Missing input video file" >&2
        return 2
    fi

    if [[ ! -f "$1" ]]; then
        echo "Error: Input file '$1' does not exist" >&2
        return 1
    fi

    # Dependency check
    if ! command -v ffmpeg &> /dev/null; then
        echo "Error: ffmpeg not installed. Install with: brew install ffmpeg" >&2
        return 1
    fi

    local input="$1"
    local output="${input%.*}_noaudio.mp4"

    # Process video
    if ! ffmpeg -i "$input" -c:v libx264 -crf 23 -preset fast -an -movflags +faststart "$output" 2>/dev/null; then
        echo "Error: Failed to process video file '$input'" >&2
        return 1
    fi

    echo "Created: $output"
}

convert-to-mp3() {
    if [[ "$1" == "-h" || "$1" == "--help" || -z "$1" ]]; then
        cat << EOF
Usage: kit convert-to-mp3 <input_media_file>
Description: Extract audio from video file and convert to MP3 format (320kbps)
Example: kit convert-to-mp3 video.mkv
Output: Creates video.mp3
EOF
        return 0
    fi

    # Input validation
    if [[ -z "$1" ]]; then
        echo "Error: Missing input media file" >&2
        return 2
    fi

    if [[ ! -f "$1" ]]; then
        echo "Error: Input file '$1' does not exist" >&2
        return 1
    fi

    # Dependency check
    if ! command -v ffmpeg &> /dev/null; then
        echo "Error: ffmpeg not installed. Install with: brew install ffmpeg" >&2
        return 1
    fi

    local input="$1"
    local output="${input%.*}.mp3"

    # Convert to MP3
    if ! ffmpeg -i "$input" -vn -acodec libmp3lame -ab 320k "$output" 2>/dev/null; then
        echo "Error: Failed to convert '$input' to MP3" >&2
        return 1
    fi

    echo "Created: $output"
}