#!/usr/bin/env bash
# shellcheck shell=bash
# send-to-sftp lib — rsync wrapper + progress parsing

_TRANSPORT_STDERR=""
_TRANSPORT_ERROR=""

transport_send() {
    local host="$1"
    local remote_dir="$2"
    shift 2

    local stderr_file
    stderr_file=$(mktemp)

    # shellcheck disable=SC2086
    rsync ${RSYNC_FLAGS:--az --partial --info=progress2} -e ssh \
        "$@" "${host}:${remote_dir}/" 2>"$stderr_file"
    local rc=$?

    _TRANSPORT_STDERR=$(<"$stderr_file")
    if (( rc != 0 )); then
        _TRANSPORT_ERROR=$(tail -5 "$stderr_file")
    else
        _TRANSPORT_ERROR=""
    fi

    rm -f "$stderr_file"
    return "$rc"
}

transport_send_with_progress() {
    local host="$1"
    local remote_dir="$2"
    shift 2

    local stderr_file
    stderr_file=$(mktemp)

    # shellcheck disable=SC2086
    rsync ${RSYNC_FLAGS:--az --partial --info=progress2} -e ssh \
        "$@" "${host}:${remote_dir}/" \
        2> >(tee "$stderr_file" | while IFS= read -r line; do
            pct=$(_parse_rsync_progress "$line")
            if [[ -n "$pct" ]]; then
                echo "$pct"
            fi
        done | ui_progress "Uploading to ${host}:${remote_dir}..."
    )
    local rc=$?

    wait

    _TRANSPORT_STDERR=$(<"$stderr_file")
    if (( rc != 0 )); then
        _TRANSPORT_ERROR=$(tail -5 "$stderr_file")
    else
        _TRANSPORT_ERROR=""
    fi

    rm -f "$stderr_file"
    return "$rc"
}

_parse_rsync_progress() {
    local line="$1"
    if [[ "$line" =~ ([0-9]+)% ]]; then
        echo "${BASH_REMATCH[1]}"
    fi
}

transport_count_items() {
    local total=0
    local path
    for path in "$@"; do
        if [[ ! -e "$path" ]]; then
            continue
        elif [[ -f "$path" ]]; then
            ((total++))
        elif [[ -d "$path" ]]; then
            local count
            count=$(find "$path" | wc -l)
            ((total += count))
        fi
    done
    echo "$total"
}
