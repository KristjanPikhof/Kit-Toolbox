#!/bin/zsh
# kit-files.zsh - Shared file input discovery for Kit commands.

if (( ${+_KIT_FILES_ZSH_LOADED} )); then
    return 0
fi
typeset -g _KIT_FILES_ZSH_LOADED=1

_kit_file_has_extension() {
    local file="$1"
    shift

    local extension="${file##*.}"
    local supported_extension
    for supported_extension in "$@"; do
        if [[ "${extension:l}" == "${supported_extension:l}" ]]; then
            return 0
        fi
    done
    return 1
}

_kit_is_image_file() {
    _kit_file_has_extension "$1" jpg jpeg png gif webp bmp tiff tif heic heif avif svg ico
}

_kit_is_webp_source_file() {
    _kit_file_has_extension "$1" png jpg jpeg heic
}

_kit_is_media_file() {
    _kit_file_has_extension "$1" \
        mp4 m4v mov mkv webm avi mpg mpeg ts mts m2ts 3gp ogv \
        mp3 m4a aac wav flac ogg opus wma aiff aif caf
}

_kit_is_video_file() {
    _kit_file_has_extension "$1" mp4 m4v mov mkv webm avi mpg mpeg ts mts m2ts 3gp ogv
}

_kit_is_pdf_file() {
    _kit_file_has_extension "$1" pdf
}

_kit_prepare_output_dir() {
    local output_dir="$1"
    [[ -z "$output_dir" ]] && return 0

    if [[ -e "$output_dir" && ! -d "$output_dir" ]]; then
        echo "Error: Output directory path is not a directory: $output_dir" >&2
        return 1
    fi
    if [[ ! -d "$output_dir" ]] && ! mkdir -p "$output_dir"; then
        echo "Error: Cannot create output directory: $output_dir" >&2
        return 1
    fi
}

# Resolve files and directories into deduplicated global arrays:
# `reply` contains each file, `reply_origins` contains the directory argument it
# came from, and `reply_relatives` contains its path below that directory.
# Explicit files have an empty origin and use their filename as the relative path.
_kit_collect_files() {
    emulate -L zsh
    setopt local_options no_unset

    local predicate="$1"
    local recursive="$2"
    local label="$3"
    shift 3

    typeset -ga reply reply_origins reply_relatives
    reply=()
    reply_origins=()
    reply_relatives=()
    if [[ $# -eq 0 ]]; then
        echo "Error: At least one file or directory is required" >&2
        return 2
    fi

    local -A seen=()
    local -a candidates=()
    local target candidate canonical origin relative
    local invalid=false

    for target in "$@"; do
        if [[ -f "$target" ]]; then
            if ! "$predicate" "$target"; then
                echo "Error: '$target' is not a supported $label file" >&2
                invalid=true
                continue
            fi
            candidates=("$target")
            origin=""
        elif [[ -d "$target" ]]; then
            origin="${target%/}"
            [[ -z "$origin" ]] && origin="/"
            if [[ "$recursive" == true ]]; then
                candidates=("$target"/**/*(ND.))
            else
                candidates=("$target"/*(ND.))
            fi
        else
            echo "Error: File or directory not found: $target" >&2
            invalid=true
            continue
        fi

        for candidate in "${candidates[@]}"; do
            "$predicate" "$candidate" || continue
            canonical="${candidate:A}"
            if [[ -z "${seen[$canonical]:-}" ]]; then
                seen[$canonical]=1
                reply+=("$candidate")
                reply_origins+=("$origin")
                if [[ -n "$origin" ]]; then
                    relative="${candidate#${origin%/}/}"
                else
                    relative="${candidate:t}"
                fi
                reply_relatives+=("$relative")
            fi
        done
    done

    if [[ "$invalid" == true ]]; then
        reply=()
        reply_origins=()
        reply_relatives=()
        return 1
    fi

    if [[ ${#reply[@]} -eq 0 ]]; then
        echo "Error: No supported $label files found" >&2
        return 1
    fi

    return 0
}

# Remove files found inside an automatically generated result folder. Explicitly
# targeting that result folder still works because it becomes the input origin.
_kit_exclude_collected_subdir() {
    local excluded="$1"
    local -a kept_files=() kept_origins=() kept_relatives=()
    local index relative

    for ((index=1; index<=${#reply[@]}; index++)); do
        relative="${reply_relatives[$index]}"
        if [[ -n "${reply_origins[$index]}" && ( "$relative" == "$excluded" || "$relative" == "$excluded"/* ) ]]; then
            continue
        fi
        kept_files+=("${reply[$index]}")
        kept_origins+=("${reply_origins[$index]}")
        kept_relatives+=("$relative")
    done

    reply=("${kept_files[@]}")
    reply_origins=("${kept_origins[@]}")
    reply_relatives=("${kept_relatives[@]}")
}

# Set REPLY to a predictable output path. Files passed directly get a sibling
# output. Files discovered through a directory go into its result folder while
# preserving subdirectories.
_kit_default_output_path() {
    local input="$1"
    local origin="$2"
    local relative="$3"
    local result_folder="$4"
    local suffix="$5"
    local extension="$6"
    local output_dir base relative_dir

    base="${relative:t:r}"
    if [[ -n "$origin" ]]; then
        relative_dir="${relative:h}"
        output_dir="$origin/$result_folder"
        [[ "$relative_dir" != "." ]] && output_dir="$output_dir/$relative_dir"
    else
        output_dir="${input:h}"
    fi

    REPLY="$output_dir/${base}${suffix}.${extension}"
}
