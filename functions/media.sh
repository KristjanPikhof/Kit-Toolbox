# media.sh - Media processing utilities using yt-dlp and ffmpeg
# Category: Media Processing
# Description: Video and audio processing tools using yt-dlp and ffmpeg
# Dependencies: yt-dlp, ffmpeg
# Functions: yt-download, remove-audio, convert-to-mp3, compress-video

_kit_media_normalize_path() {
    local file_path="$1"
    local directory
    local filename

    directory=$(dirname "$file_path")
    filename=$(basename "$file_path")
    directory=$(cd "$directory" 2>/dev/null && pwd -P) || return 1

    printf '%s/%s\n' "$directory" "$filename"
}

_kit_media_validate_output() {
    local input="$1"
    local output="$2"
    local force="$3"
    local input_path
    local output_path

    input_path=$(_kit_media_normalize_path "$input") || {
        echo "Error: Cannot resolve input path '$input'" >&2
        return 2
    }
    output_path=$(_kit_media_normalize_path "$output") || {
        echo "Error: Output directory for '$output' does not exist" >&2
        return 2
    }

    if [[ "$input_path" == "$output_path" ]] || [[ -e "$output" && "$input" -ef "$output" ]]; then
        echo "Error: Input and output must be different files" >&2
        return 2
    fi

    if [[ -e "$output" && "$force" != true ]]; then
        echo "Error: Output file '$output' already exists. Use --force to overwrite." >&2
        return 1
    fi

    return 0
}

_kit_media_run_ffmpeg() {
    local input="$1"
    local output="$2"
    local force="$3"
    local verbose="$4"
    shift 4

    _kit_media_validate_output "$input" "$output" "$force" || return $?

    local output_base="${output%.*}"
    local output_extension="${output##*.}"
    local temporary_output="${output_base}.kit-tmp.$$.$RANDOM.${output_extension}"
    local -a ffmpeg_cmd=(ffmpeg -hide_banner -nostdin)

    while [[ -e "$temporary_output" ]]; do
        temporary_output="${output_base}.kit-tmp.$$.$RANDOM.${output_extension}"
    done

    if [[ "$verbose" != true ]]; then
        ffmpeg_cmd+=(-loglevel error)
    fi
    ffmpeg_cmd+=(-i "$input" "$@" "$temporary_output")

    if ! "${ffmpeg_cmd[@]}"; then
        rm -f "$temporary_output"
        echo "Error: FFmpeg failed while creating '$output'" >&2
        return 1
    fi

    if [[ ! -s "$temporary_output" ]]; then
        rm -f "$temporary_output"
        echo "Error: FFmpeg created an empty output for '$output'" >&2
        return 1
    fi

    if ! mv -f "$temporary_output" "$output"; then
        rm -f "$temporary_output"
        echo "Error: Failed to move completed output to '$output'" >&2
        return 1
    fi

    return 0
}

_kit_media_report() {
    local action="$1"
    local input="$2"
    local output="$3"
    local input_size
    local output_size
    local input_bytes
    local output_bytes

    input_size=$(du -h "$input" | awk '{print $1}')
    output_size=$(du -h "$output" | awk '{print $1}')
    input_bytes=$(wc -c < "$input" | tr -d ' ')
    output_bytes=$(wc -c < "$output" | tr -d ' ')

    echo "$action: $output ($input_size → $output_size)"
    if [[ "$output_bytes" -gt "$input_bytes" ]]; then
        echo "Warning: Output is larger than the input; try a smaller quality preset or bitrate." >&2
    fi
}

yt-download() {
    local mode=""
    local url=""
    local quality=""
    local output=""
    local force=false
    local verbose=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit yt-download <mode> <url> [quality] [options]
Description: Download YouTube videos or audio using yt-dlp
Modes: mp3 (audio only), mp4 (video)
Quality: For mp3: 0 (best) to 10 (worst), or a bitrate such as 128K; default 5
         For mp4: yt-dlp format selector, default "bv*+ba/b"
Options:
  -o, --output TEMPLATE  yt-dlp output template
  -f, --force            Allow overwriting downloaded files
  -v, --verbose          Show yt-dlp progress and diagnostics
Examples:
  kit yt-download mp3 "https://youtube.com/watch?v=..."
  kit yt-download mp3 "https://youtube.com/watch?v=..." 128K
  kit yt-download mp4 "https://youtube.com/watch?v=..."
EOF
                return 0
                ;;
            -o|--output)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires an output template" >&2
                    return 2
                fi
                output="$2"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
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
                if [[ -z "$mode" ]]; then
                    mode="$1"
                elif [[ -z "$url" ]]; then
                    url="$1"
                elif [[ -z "$quality" ]]; then
                    quality="$1"
                else
                    echo "Error: Unexpected argument '$1'" >&2
                    return 2
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$mode" || -z "$url" ]]; then
        echo "Error: Missing required arguments. Use -h for help." >&2
        return 2
    fi

    local opts=(--no-playlist --embed-metadata --embed-thumbnail)

    _kit_require yt-dlp || return 1

    if [[ "$force" == true ]]; then
        opts+=(--force-overwrites)
    else
        opts+=(--no-overwrites)
    fi
    if [[ -n "$output" ]]; then
        opts+=(-o "$output")
    fi
    if [[ "$verbose" != true ]]; then
        opts+=(--quiet)
    fi

    case "$mode" in
        mp3)
            quality="${quality:-5}"
            if [[ "$quality" =~ ^[0-9]+$ ]]; then
                if [[ "$quality" -lt 0 || "$quality" -gt 10 ]]; then
                    echo "Error: MP3 quality must be between 0 and 10" >&2
                    return 2
                fi
            elif ! [[ "$quality" =~ ^[0-9]+[kK]$ ]]; then
                echo "Error: MP3 quality must be 0-10 or a bitrate such as 128K" >&2
                return 2
            fi

            if ! yt-dlp "${opts[@]}" -x --audio-format mp3 --audio-quality "$quality" -- "$url"; then
                echo "Error: Failed to download audio from URL: $url" >&2
                return 1
            fi
            ;;
        mp4)
            if ! yt-dlp "${opts[@]}" --merge-output-format mp4 --remux-video mp4 -f "${quality:-bv*+ba/b}" -- "$url"; then
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
    local reencode=false
    local verbose=false
    local input=""
    local output=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit remove-audio <input_video_file> [options]
Description: Remove audio without re-encoding the video by default
Options:
  -o, --output FILE  Output file (default: input_noaudio.<same extension>)
  -r, --reencode     Re-encode video as H.264 instead of copying it
  -f, --force        Safely replace the output after conversion succeeds
  -v, --verbose      Show FFmpeg progress and diagnostics
Example: kit remove-audio video.mp4
Output: Creates video_noaudio.mp4
EOF
                return 0
                ;;
            -o|--output)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires an output file" >&2
                    return 2
                fi
                output="$2"
                shift 2
                ;;
            -r|--reencode)
                reencode=true
                shift
                ;;
            -f|--force)
                force=true
                shift
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
                if [[ -z "$input" ]]; then
                    input="$1"
                else
                    echo "Error: Unexpected argument '$1'" >&2
                    return 2
                fi
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

    _kit_require ffmpeg || return 1

    if [[ -z "$output" ]]; then
        if [[ "$reencode" == true ]]; then
            output="${input%.*}_noaudio.mp4"
        else
            local input_name="${input##*/}"
            local input_extension="mkv"
            if [[ "$input_name" == *.* ]]; then
                input_extension="${input##*.}"
            fi
            output="${input%.*}_noaudio.${input_extension}"
        fi
    fi

    local -a ffmpeg_args=(-map 0:v:0 -map_metadata 0 -an)
    if [[ "$reencode" == true ]]; then
        ffmpeg_args+=(-c:v libx264 -crf 23 -preset fast)
    else
        ffmpeg_args+=(-c:v copy)
    fi
    case "${output##*.}" in
        mp4|MP4|m4v|M4V|mov|MOV)
            ffmpeg_args+=(-movflags +faststart)
            ;;
    esac

    _kit_media_run_ffmpeg "$input" "$output" "$force" "$verbose" "${ffmpeg_args[@]}" || return $?

    _kit_media_report "Created" "$input" "$output"
}

convert-to-mp3() {
    local force=false
    local verbose=false
    local input=""
    local output=""
    local preset="standard"
    local bitrate=""
    local preset_set=false
    local bitrate_set=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit convert-to-mp3 <input_media_file> [options]
Description: Extract audio and convert it to a size-conscious MP3
Options:
  -p, --preset NAME  Quality profile (default: standard)
                     speech: 48kbps mono at 24kHz
                     compact: smaller VBR (quality 7)
                     standard: balanced VBR (quality 5)
                     high: high-quality VBR (quality 2)
                     maximum: constant 320kbps
  -b, --bitrate NUM  Custom bitrate in kbps (8-320)
  -o, --output FILE  Output file (default: input.mp3)
  -f, --force        Safely replace the output after conversion succeeds
  -v, --verbose      Show FFmpeg progress and diagnostics
Examples:
  kit convert-to-mp3 video.mkv
  kit convert-to-mp3 recording.m4a --preset speech
  kit convert-to-mp3 music.m4a --bitrate 128 -o music.mp3
Output: Creates video.mp3
EOF
                return 0
                ;;
            -p|--preset)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a preset name" >&2
                    return 2
                fi
                preset="$2"
                preset_set=true
                shift 2
                ;;
            -b|--bitrate)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a bitrate" >&2
                    return 2
                fi
                bitrate="$2"
                bitrate_set=true
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
            -f|--force)
                force=true
                shift
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
                if [[ -z "$input" ]]; then
                    input="$1"
                else
                    echo "Error: Unexpected argument '$1'" >&2
                    return 2
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

    _kit_require ffmpeg || return 1

    if [[ "$preset_set" == true && "$bitrate_set" == true ]]; then
        echo "Error: Use either --preset or --bitrate, not both" >&2
        return 2
    fi

    if [[ "$bitrate_set" == true ]]; then
        if ! [[ "$bitrate" =~ ^[0-9]+$ ]] || [[ "$bitrate" -lt 8 || "$bitrate" -gt 320 ]]; then
            echo "Error: Bitrate must be an integer between 8 and 320 kbps" >&2
            return 2
        fi
    else
        case "$preset" in
            speech|compact|standard|high|maximum) ;;
            *)
                echo "Error: Invalid preset '$preset'. Use speech, compact, standard, high, or maximum." >&2
                return 2
                ;;
        esac
    fi

    if [[ -z "$output" ]]; then
        output="${input%.*}.mp3"
    fi
    local output_extension
    output_extension=$(printf '%s' "${output##*.}" | tr '[:upper:]' '[:lower:]')
    if [[ "$output_extension" != "mp3" ]]; then
        echo "Error: MP3 output file must use the .mp3 extension" >&2
        return 2
    fi

    local -a ffmpeg_args=(-map 0:a:0 -map_metadata 0 -vn -c:a libmp3lame)
    if [[ "$bitrate_set" == true ]]; then
        ffmpeg_args+=(-b:a "${bitrate}k")
    else
        case "$preset" in
            speech)
                ffmpeg_args+=(-b:a 48k -ac 1 -ar 24000)
                ;;
            compact)
                ffmpeg_args+=(-q:a 7)
                ;;
            standard)
                ffmpeg_args+=(-q:a 5)
                ;;
            high)
                ffmpeg_args+=(-q:a 2)
                ;;
            maximum)
                ffmpeg_args+=(-b:a 320k)
                ;;
        esac
    fi
    ffmpeg_args+=(-id3v2_version 3)

    _kit_media_run_ffmpeg "$input" "$output" "$force" "$verbose" "${ffmpeg_args[@]}" || return $?

    _kit_media_report "Created" "$input" "$output"
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
  -w, --width NUM      Maximum width (default: 1280, never upscales; -1 disables)
  -b, --bitrate NUM    Audio bitrate in k (default: 128)
  -f, --force          Safely replace the output after conversion succeeds
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
    local force=false
    local verbose=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o|--output)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires an output file" >&2
                    return 2
                fi
                output="$2"
                shift 2
                ;;
            -c|--crf)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a CRF value" >&2
                    return 2
                fi
                crf="$2"
                shift 2
                ;;
            -p|--preset)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires an encoder preset" >&2
                    return 2
                fi
                preset="$2"
                shift 2
                ;;
            -w|--width)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires a maximum width" >&2
                    return 2
                fi
                width="$2"
                shift 2
                ;;
            -b|--bitrate)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    echo "Error: $1 requires an audio bitrate" >&2
                    return 2
                fi
                bitrate="${2}k"
                shift 2
                ;;
            -f|--force)
                force=true
                shift
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
                if [[ -z "$input" ]]; then
                    input="$1"
                else
                    echo "Error: Unexpected argument '$1'" >&2
                    return 2
                fi
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

    _kit_require ffmpeg || return 1

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

    # Validate width (must be -1 or a non-zero positive integer)
    if [[ "$width" != "-1" ]] && ! [[ "$width" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: Invalid width '$width'. Must be -1 or a positive integer." >&2
        return 2
    fi

    local bitrate_value="${bitrate%k}"
    if ! [[ "$bitrate_value" =~ ^[0-9]+$ ]] || [[ "$bitrate_value" -lt 8 || "$bitrate_value" -gt 512 ]]; then
        echo "Error: Invalid audio bitrate '$bitrate_value'. Must be between 8 and 512 kbps." >&2
        return 2
    fi

    local -a ffmpeg_args=(-map 0:v:0 -map "0:a:0?" -map_metadata 0 -c:v libx264 -crf "$crf" -preset "$preset" -c:a aac -b:a "$bitrate")

    if [[ "$width" != "-1" ]]; then
        ffmpeg_args+=(-vf "scale='min(iw,${width})':-2")
    fi

    case "${output##*.}" in
        mp4|MP4|m4v|M4V|mov|MOV)
            ffmpeg_args+=(-movflags +faststart)
            ;;
    esac

    _kit_media_run_ffmpeg "$input" "$output" "$force" "$verbose" "${ffmpeg_args[@]}" || return $?

    _kit_media_report "Compressed" "$input" "$output"
}
