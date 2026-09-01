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

# Resolve files and directories into a deduplicated file list in the global
# `reply` array. Explicit files must match the predicate. Directories contribute
# only matching files and are scanned recursively when requested.
_kit_collect_files() {
    emulate -L zsh
    setopt local_options no_unset

    local predicate="$1"
    local recursive="$2"
    local label="$3"
    shift 3

    reply=()
    if [[ $# -eq 0 ]]; then
        echo "Error: At least one file or directory is required" >&2
        return 2
    fi

    local -A seen=()
    local -a candidates=()
    local target candidate canonical
    local invalid=false

    for target in "$@"; do
        if [[ -f "$target" ]]; then
            if ! "$predicate" "$target"; then
                echo "Error: '$target' is not a supported $label file" >&2
                invalid=true
                continue
            fi
            candidates=("$target")
        elif [[ -d "$target" ]]; then
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
            fi
        done
    done

    if [[ "$invalid" == true ]]; then
        reply=()
        return 1
    fi

    if [[ ${#reply[@]} -eq 0 ]]; then
        echo "Error: No supported $label files found" >&2
        return 1
    fi

    return 0
}
