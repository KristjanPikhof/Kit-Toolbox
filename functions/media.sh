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

_kit_media_stem() {
    local file_path="$1"
    local directory
    local filename

    directory=$(dirname "$file_path")
    filename=$(basename "$file_path")
    if [[ "${filename#.}" == *.* ]]; then
        filename="${filename%.*}"
    fi

    if [[ "$directory" == "." ]]; then
        printf '%s\n' "$filename"
    else
        printf '%s/%s\n' "$directory" "$filename"
    fi
}

_kit_media_temporary_output() {
    local output="$1"
    local directory
    local filename
    local temporary_name

    directory=$(dirname "$output")
    filename=$(basename "$output")
    temporary_name=".kit-tmp.$$.$RANDOM.${filename}"

    if [[ "$directory" == "." ]]; then
        printf '%s\n' "$temporary_name"
    else
        printf '%s/%s\n' "$directory" "$temporary_name"
    fi
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

    if [[ ( -e "$output" || -L "$output" ) && "$force" != true ]]; then
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

    local temporary_output
    local -a ffmpeg_cmd=(ffmpeg -hide_banner -nostdin)

    temporary_output=$(_kit_media_temporary_output "$output")
    while [[ -e "$temporary_output" ]]; do
        temporary_output=$(_kit_media_temporary_output "$output")
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

    local move_option
    if [[ "$force" == true ]]; then
        move_option="-f"
    else
        move_option="-n"
    fi

    if ! mv "$move_option" "$temporary_output" "$output"; then
        rm -f "$temporary_output"
        echo "Error: Failed to move completed output to '$output'" >&2
        return 1
    fi

    if [[ "$force" != true && ( -e "$temporary_output" || -L "$temporary_output" ) ]]; then
        rm -f "$temporary_output"
        echo "Error: Output file '$output' was created while FFmpeg was running; refusing to overwrite." >&2
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
        echo "Warning: Output is larger than the input; review the selected conversion settings." >&2
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
    _kit_require ffmpeg || return 1

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
            elif [[ "$quality" =~ ^[0-9]+[kK]$ ]]; then
                if [[ "${quality%[kK]}" -lt 1 ]]; then
                    echo "Error: MP3 bitrate must be greater than zero" >&2
                    return 2
                fi
            else
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
    local output=""
    local output_dir=""
    local recursive=false
    local -a targets=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit remove-audio <path>... [options]
Description: Remove audio from one or more videos without re-encoding by default
Options:
  -o, --output FILE      Output file, valid with one input only
  -d, --output-dir DIR   Put every output in DIR
  -r, --recursive        Process directories recursively
  --reencode             Re-encode video as H.264 instead of copying it
  -f, --force            Safely replace outputs after conversion succeeds
  -v, --verbose          Show FFmpeg progress and diagnostics
Examples:
  kit remove-audio video.mp4
  kit remove-audio intro.mp4 outro.mov
  kit remove-audio ./videos --recursive --output-dir ./silent
Output: Creates files with a _noaudio suffix
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
            --reencode)
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
                targets+=("$1")
                shift
                ;;
        esac
    done

    if [[ -n "$output" && -n "$output_dir" ]]; then
        echo "Error: Use either --output or --output-dir, not both" >&2
        return 2
    fi

    _kit_collect_files _kit_is_video_file "$recursive" video "${targets[@]}" || return $?
    local -a inputs=("${reply[@]}")
    if [[ -n "$output" && ${#inputs[@]} -ne 1 ]]; then
        echo "Error: --output requires exactly one input. Use --output-dir for batches." >&2
        return 2
    fi

    _kit_require ffmpeg || return 1
    _kit_prepare_output_dir "$output_dir" || return 1

    local input input_stem input_extension output_extension current_output
    local -a outputs=()
    local -A seen_outputs=()
    for input in "${inputs[@]}"; do
        input_stem=$(_kit_media_stem "$input")
        input_extension="${input:e}"
        [[ -z "$input_extension" ]] && input_extension="mkv"
        output_extension="$input_extension"
        [[ "$reencode" == true ]] && output_extension="mp4"
        if [[ -n "$output" ]]; then
            current_output="$output"
        elif [[ -n "$output_dir" ]]; then
            current_output="$output_dir/${input:t:r}_noaudio.${output_extension}"
        elif [[ "$reencode" == true ]]; then
            current_output="${input_stem}_noaudio.mp4"
        else
            current_output="${input_stem}_noaudio.${input_extension}"
        fi
        if [[ -n "${seen_outputs[${current_output:A}]:-}" ]]; then
            echo "Error: Multiple inputs would create '$current_output'" >&2
            return 1
        fi
        seen_outputs[${current_output:A}]=1
        _kit_media_validate_output "$input" "$current_output" "$force" || return $?
        outputs+=("$current_output")
    done

    local success=0
    local failed=0
    local index
    for ((index=1; index<=${#inputs[@]}; index++)); do
        input="${inputs[$index]}"
        current_output="${outputs[$index]}"
        local -a ffmpeg_args=(-map 0 -map -0:a -map_metadata 0 -map_chapters 0 -c copy)
        [[ "$reencode" == true ]] && ffmpeg_args+=(-c:v libx264 -crf 23 -preset fast)
        case "${current_output:e}" in
            mp4|MP4|m4v|M4V|mov|MOV) ffmpeg_args+=(-movflags +faststart) ;;
        esac
        if _kit_media_run_ffmpeg "$input" "$current_output" "$force" "$verbose" "${ffmpeg_args[@]}"; then
            _kit_media_report "Created" "$input" "$current_output"
            ((success++))
        else
            ((failed++))
        fi
    done
    echo "Processed $success file(s); $failed failed"
    [[ $failed -eq 0 ]]
}

convert-to-mp3() {
    local force=false
    local verbose=false
    local output=""
    local output_dir=""
    local recursive=false
    local preset="standard"
    local bitrate=""
    local preset_set=false
    local bitrate_set=false
    local -a targets=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat << EOF
Usage: kit convert-to-mp3 <path>... [options]
Description: Extract audio from one or more media files and convert it to MP3
Options:
  -p, --preset NAME  Quality profile (default: standard)
                     speech: 48kbps mono at 24kHz
                     compact: smaller VBR (quality 7)
                     standard: balanced VBR (quality 5)
                     high: high-quality VBR (quality 2)
                     maximum: constant 320kbps
  -b, --bitrate NUM  Custom bitrate in kbps (8-320)
  -o, --output FILE      Output file, valid with one input only
  -d, --output-dir DIR   Put every output in DIR
  -r, --recursive        Process directories recursively
  -f, --force            Safely replace outputs after conversion succeeds
  -v, --verbose          Show FFmpeg progress and diagnostics
Examples:
  kit convert-to-mp3 video.mkv
  kit convert-to-mp3 intro.mov outro.m4a
  kit convert-to-mp3 ./recordings --recursive --preset speech
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
                targets+=("$1")
                shift
                ;;
        esac
    done

    if [[ -n "$output" && -n "$output_dir" ]]; then
        echo "Error: Use either --output or --output-dir, not both" >&2
        return 2
    fi

    _kit_collect_files _kit_is_media_file "$recursive" media "${targets[@]}" || return $?
    local -a inputs=("${reply[@]}")
    if [[ -n "$output" && ${#inputs[@]} -ne 1 ]]; then
        echo "Error: --output requires exactly one input. Use --output-dir for batches." >&2
        return 2
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

    if [[ -n "$output" && "${output:e:l}" != "mp3" ]]; then
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

    _kit_prepare_output_dir "$output_dir" || return 1
    local input current_output
    local -a outputs=()
    local -A seen_outputs=()
    for input in "${inputs[@]}"; do
        if [[ -n "$output" ]]; then
            current_output="$output"
        elif [[ -n "$output_dir" ]]; then
            current_output="$output_dir/${input:t:r}.mp3"
        else
            current_output="$(_kit_media_stem "$input").mp3"
        fi
        if [[ -n "${seen_outputs[${current_output:A}]:-}" ]]; then
            echo "Error: Multiple inputs would create '$current_output'" >&2
            return 1
        fi
        seen_outputs[${current_output:A}]=1
        _kit_media_validate_output "$input" "$current_output" "$force" || return $?
        outputs+=("$current_output")
    done

    local success=0
    local failed=0
    local index
    for ((index=1; index<=${#inputs[@]}; index++)); do
        input="${inputs[$index]}"
        current_output="${outputs[$index]}"
        if _kit_media_run_ffmpeg "$input" "$current_output" "$force" "$verbose" "${ffmpeg_args[@]}"; then
            _kit_media_report "Created" "$input" "$current_output"
            ((success++))
        else
            ((failed++))
        fi
    done
    echo "Processed $success file(s); $failed failed"
    [[ $failed -eq 0 ]]
}

compress-video() {
    if [[ "$1" == "-h" || "$1" == "--help" ]]; then
        cat << EOF
Usage: kit compress-video <path>... [options]
Description: Compress one or more video files
Options:
  -o, --output FILE    Output file, valid with one input only
  -d, --output-dir DIR Put every output in DIR
  -r, --recursive      Process directories recursively
  -c, --crf NUM        Quality level 18-28 (default: 23, lower=better)
  -p, --preset PRESET  Encoding speed (default: slow)
                       Options: ultrafast, superfast, veryfast, faster,
                                fast, medium, slow, slower, veryslow
  -w, --width NUM      Maximum width (default: 1280, minimum: 2; -1 disables)
  -b, --bitrate NUM    Audio bitrate in k (default: 128)
  -f, --force          Safely replace the output after conversion succeeds
  -v, --verbose        Show ffmpeg output
Examples:
  kit compress-video video.mp4
  kit compress-video intro.mp4 outro.mov
  kit compress-video ./videos --recursive --output-dir ./compressed
  kit compress-video video.mp4 -c 28 -o small.mp4
  kit compress-video video.mp4 --width 1920 --preset medium
EOF
        return 0
    fi

    local output=""
    local output_dir=""
    local recursive=false
    local crf=23
    local preset="slow"
    local width=1280
    local bitrate="128k"
    local force=false
    local verbose=false
    local -a targets=()

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
                targets+=("$1")
                shift
                ;;
        esac
    done

    if [[ -n "$output" && -n "$output_dir" ]]; then
        echo "Error: Use either --output or --output-dir, not both" >&2
        return 2
    fi

    _kit_collect_files _kit_is_video_file "$recursive" video "${targets[@]}" || return $?
    local -a inputs=("${reply[@]}")
    if [[ -n "$output" && ${#inputs[@]} -ne 1 ]]; then
        echo "Error: --output requires exactly one input. Use --output-dir for batches." >&2
        return 2
    fi

    _kit_require ffmpeg || return 1

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

    # Validate width (must be -1 or large enough to produce an even H.264 frame)
    if [[ "$width" != "-1" ]]; then
        if ! [[ "$width" =~ ^[0-9]+$ ]] || [[ "$width" -lt 2 ]]; then
            echo "Error: Invalid width '$width'. Must be -1 or an integer of at least 2." >&2
            return 2
        fi
    fi

    local bitrate_value="${bitrate%k}"
    if ! [[ "$bitrate_value" =~ ^[0-9]+$ ]] || [[ "$bitrate_value" -lt 8 || "$bitrate_value" -gt 512 ]]; then
        echo "Error: Invalid audio bitrate '$bitrate_value'. Must be between 8 and 512 kbps." >&2
        return 2
    fi

    local -a ffmpeg_args=(-map 0:v:0 -map "0:a:0?" -map_metadata 0 -c:v libx264 -crf "$crf" -preset "$preset" -c:a aac -b:a "$bitrate")

    if [[ "$width" != "-1" ]]; then
        ffmpeg_args+=(-vf "scale='trunc(min(iw,${width})/2)*2':-2")
    fi

    _kit_prepare_output_dir "$output_dir" || return 1
    local input current_output
    local -a outputs=()
    local -A seen_outputs=()
    for input in "${inputs[@]}"; do
        if [[ -n "$output" ]]; then
            current_output="$output"
        elif [[ -n "$output_dir" ]]; then
            current_output="$output_dir/${input:t:r}_compressed.mp4"
        else
            current_output="$(_kit_media_stem "$input")_compressed.mp4"
        fi
        if [[ -n "${seen_outputs[${current_output:A}]:-}" ]]; then
            echo "Error: Multiple inputs would create '$current_output'" >&2
            return 1
        fi
        seen_outputs[${current_output:A}]=1
        _kit_media_validate_output "$input" "$current_output" "$force" || return $?
        outputs+=("$current_output")
    done

    local success=0
    local failed=0
    local index
    for ((index=1; index<=${#inputs[@]}; index++)); do
        input="${inputs[$index]}"
        current_output="${outputs[$index]}"
        local -a current_args=("${ffmpeg_args[@]}")
        case "${current_output:e}" in
            mp4|MP4|m4v|M4V|mov|MOV) current_args+=(-movflags +faststart) ;;
        esac
        if _kit_media_run_ffmpeg "$input" "$current_output" "$force" "$verbose" "${current_args[@]}"; then
            _kit_media_report "Compressed" "$input" "$current_output"
            ((success++))
        else
            ((failed++))
        fi
    done
    echo "Processed $success file(s); $failed failed"
    [[ $failed -eq 0 ]]
}
