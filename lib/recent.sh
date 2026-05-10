#!/usr/bin/env bash
# shellcheck shell=bash
# send-to-sftp lib — recent destinations store

: "${RECENT_FILE:=${XDG_CONFIG_HOME:-$HOME/.config}/send-to-sftp/recent}"
: "${RECENT_LIMIT:=15}"

recent_add() {
    local host="$1"
    local path="$2"
    local entry="${host}:${path}"

    mkdir -p "$(dirname "$RECENT_FILE")"
    touch "$RECENT_FILE"

    echo "$entry" >> "$RECENT_FILE"

    _recent_dedup
    _recent_trim
}

recent_list() {
    [[ -f "$RECENT_FILE" ]] || return 0
    tac "$RECENT_FILE" | awk '!seen[$0]++' | head -n "${RECENT_LIMIT:-15}"
}

_recent_dedup() {
    local tmp
    tmp=$(mktemp)
    tac "$RECENT_FILE" | awk '!seen[$0]++' | tac > "$tmp"
    mv "$tmp" "$RECENT_FILE"
}

_recent_trim() {
    local limit="${RECENT_LIMIT:-15}"
    local line_count
    line_count=$(wc -l < "$RECENT_FILE")
    if (( line_count > limit )); then
        local tmp
        tmp=$(mktemp)
        tail -n "$limit" "$RECENT_FILE" > "$tmp"
        mv "$tmp" "$RECENT_FILE"
    fi
}
