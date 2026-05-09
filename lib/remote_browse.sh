#!/usr/bin/env bash
# shellcheck shell=bash
# send-to-sftp lib — browse remote directories over SSH

declare -gA _REMOTE_CACHE=()

_remote_list_cache_key() {
    local host="$1" path="$2"
    printf '%s:%s' "$host" "$path"
}

_remote_cache_get() {
    local key="$1"
    if [[ -v "_REMOTE_CACHE[$key]" ]]; then
        printf '%s' "${_REMOTE_CACHE[$key]}"
        return 0
    fi
    return 1
}

_remote_cache_set() {
    local key="$1" data="$2"
    _REMOTE_CACHE["$key"]="$data"
}

remote_list_dir() {
    local host="$1" path="$2"
    local cache_key output

    cache_key="$(_remote_list_cache_key "$host" "$path")"

    if _remote_cache_get "$cache_key"; then
        return 0
    fi

    local quoted_path
    quoted_path=$(printf '%q' "$path")
    # shellcheck disable=SC2029
    output=$(ssh "$host" "ls -1ap $quoted_path" 2>&1)
    local rc=$?

    if [[ $rc -ne 0 ]]; then
        echo "remote_list_dir: failed to list ${host}:${path}" >&2
        echo "$output" >&2
        return "$rc"
    fi

    _remote_cache_set "$cache_key" "$output"

    while IFS= read -r line; do
        if [[ "$line" == "./" ]]; then
            continue
        fi
        printf '%s\n' "$line"
    done <<< "$output"

    return 0
}

remote_browse() {
    local host="$1" current_dir="$2"
    local entries selection yad_rc
    local -a columns

    if [[ -z "$current_dir" ]]; then
        current_dir="~"
    fi

    while true; do
        entries=$(remote_list_dir "$host" "$current_dir")
        # shellcheck disable=SC2181
        if [[ $? -ne 0 ]]; then
            ui_error "Cannot list remote directory: ${host}:${current_dir}"
            return 1
        fi

        columns=()
        while IFS= read -r entry; do
            columns+=("$entry")
        done <<< "$entries"

        selection=$(printf '%s\n' "${columns[@]}" \
            | yad --list \
                --title="Browse ${host}:${current_dir}" \
                --text="Select a directory:" \
                --column="Entry" \
                --button="Use this directory:0" \
                --button="Cancel:1" \
                --width=500 --height=400 \
                --print-column=1 \
            2>/dev/null)
        yad_rc=$?

        if [[ $yad_rc -eq 1 ]]; then
            return 1
        fi

        if [[ $yad_rc -eq 0 && -z "$selection" ]]; then
            printf '%s\n' "$current_dir"
            return 0
        fi

        selection=$(echo "$selection" | head -1 | tr -d '|')

        if [[ -z "$selection" ]]; then
            printf '%s\n' "$current_dir"
            return 0
        fi

        if [[ "$selection" == "../" ]]; then
            current_dir=$(dirname "$current_dir")
            continue
        fi

        if [[ "$selection" == */ ]]; then
            current_dir="${current_dir%/}/${selection}"
            continue
        fi
    done

    return 1
}
