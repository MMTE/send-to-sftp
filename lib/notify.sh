#!/usr/bin/env bash
# shellcheck shell=bash
# send-to-sftp lib — libnotify wrapper

_NOTIFY_APP_NAME="send-to-sftp"

_has_notify() {
    command -v notify-send &>/dev/null
}

notify() {
    local message="$1"
    local severity="${2:-info}"

    if _has_notify; then
        local urgency icon
        case "$severity" in
            success) urgency="normal"; icon="folder-remote" ;;
            warning) urgency="normal"; icon="dialog-warning" ;;
            error)   urgency="critical"; icon="dialog-error" ;;
            *)       urgency="normal"; icon="folder-remote" ;;
        esac

        notify-send \
            -a "$_NOTIFY_APP_NAME" \
            -u "$urgency" \
            -i "$icon" \
            "Send to SFTP" \
            "$message"
    else
        echo "[send-to-sftp] $message" >&2
    fi
    return 0
}

notify_progress() {
    local message="$1"
    local percent="$2"
    local replace_id="${3:-}"

    if _has_notify; then
        local -a cmd=(
            notify-send
            -a "$_NOTIFY_APP_NAME"
            -u "normal"
            -i "folder-remote"
            -h "int:value:${percent}"
            -h "string:synchronous:send-to-sftp"
        )

        if [[ -n "$replace_id" ]]; then
            cmd+=( -r "$replace_id" )
        fi

        cmd+=(
            "Send to SFTP"
            "${percent}% — ${message}"
        )

        "${cmd[@]}"
    else
        echo "[send-to-sftp] ${percent}% — ${message}" >&2
    fi
    return 0
}

notify_result() {
    local success="$1"
    local message="$2"

    if (( success == 0 )); then
        notify "$message" "success"
    else
        notify "$message" "error"
    fi
}
