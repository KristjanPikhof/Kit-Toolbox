#!/bin/zsh
# kit-core.zsh - Pure helper functions for Kit metadata/config parsing.
#
# This library is sourced by the loader and must remain side-effect-free.

if (( ${+_KIT_CORE_ZSH_LOADED} )); then
    return 0
fi
typeset -g _KIT_CORE_ZSH_LOADED=1

_kit_validate_shell_identifier() {
    local name="$1"
    [[ "$name" =~ '^[a-zA-Z_][a-zA-Z0-9_]*$' ]]
}

_kit_parse_config_line() {
    local line="$1" name_var="$2" value_var="$3" desc_var="$4"
    local parsed_name parsed_value parsed_desc remainder output_var

    for output_var in "$name_var" "$value_var" "$desc_var"; do
        [[ -z "$output_var" ]] && continue
        _kit_validate_shell_identifier "$output_var" || return 3
    done

    [[ -z "$line" ]] && return 1
    [[ "$line" =~ '^[[:space:]]*$' ]] && return 1
    [[ "$line" =~ '^[[:space:]]*#' ]] && return 1

    if [[ "$line" != *'|'* ]]; then
        return 2
    fi

    parsed_name="${line%%|*}"
    remainder="${line#*|}"

    if [[ "$remainder" == *'|'* ]]; then
        parsed_value="${remainder%%|*}"
        parsed_desc="${remainder#*|}"
    else
        parsed_value="$remainder"
        parsed_desc=""
    fi

    if [[ -n "$name_var" ]]; then eval "$name_var=${(qqq)parsed_name}"; fi
    if [[ -n "$value_var" ]]; then eval "$value_var=${(qqq)parsed_value}"; fi
    if [[ -n "$desc_var" ]]; then eval "$desc_var=${(qqq)parsed_desc}"; fi
    return 0
}

_kit_read_shortcut_entries() {
    local config_file="$1"
    local line entry_name entry_value entry_desc

    [[ -f "$config_file" ]] || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        _kit_parse_config_line "$line" entry_name entry_value entry_desc || continue
        _kit_validate_shell_identifier "$entry_name" || continue
        print -r -- "$entry_name|$entry_value|$entry_desc"
    done < "$config_file"
}

_kit_read_editor_entries() {
    local config_file="$1"
    local line entry_name entry_value entry_desc

    [[ -f "$config_file" ]] || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        _kit_parse_config_line "$line" entry_name entry_value entry_desc || continue
        _kit_validate_shell_identifier "$entry_name" || continue
        print -r -- "$entry_name|$entry_value|$entry_desc"
    done < "$config_file"
}

_kit_find_shortcut() {
    local config_file="$1" wanted_name="$2"
    local line entry_name entry_value entry_desc

    [[ -f "$config_file" ]] || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        _kit_parse_config_line "$line" entry_name entry_value entry_desc || continue
        _kit_validate_shell_identifier "$entry_name" || continue
        if [[ "$entry_name" == "$wanted_name" ]]; then
            print -r -- "$entry_name|$entry_value|$entry_desc"
            return 0
        fi
    done < "$config_file"

    return 1
}

_kit_find_editor() {
    local config_file="$1" wanted_name="$2"
    local line entry_name entry_value entry_desc

    [[ -f "$config_file" ]] || return 1

    while IFS= read -r line || [[ -n "$line" ]]; do
        _kit_parse_config_line "$line" entry_name entry_value entry_desc || continue
        _kit_validate_shell_identifier "$entry_name" || continue
        if [[ "$entry_name" == "$wanted_name" ]]; then
            print -r -- "$entry_name|$entry_value|$entry_desc"
            return 0
        fi
    done < "$config_file"

    return 1
}

_kit_read_module_headers() {
    local functions_dir="$1"
    local module_file line category functions description

    [[ -d "$functions_dir" ]] || return 1

    for module_file in "$functions_dir"/*.sh(N); do
        category=""
        functions=""
        description=""

        while IFS= read -r line || [[ -n "$line" ]]; do
            case "$line" in
                '# Category:'*) category="${line#'# Category:'}"; category="${category#${category%%[![:space:]]*}}" ;;
                '# Functions:'*) functions="${line#'# Functions:'}"; functions="${functions#${functions%%[![:space:]]*}}" ;;
                '# Description:'*) description="${line#'# Description:'}"; description="${description#${description%%[![:space:]]*}}" ;;
            esac

            if [[ -n "$category" && -n "$functions" && -n "$description" ]]; then
                break
            fi
        done < "$module_file"

        [[ -n "$category" && -n "$functions" ]] || continue
        print -r -- "${module_file:t}|$category|$functions|$description"
    done
}
