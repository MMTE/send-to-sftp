#!/usr/bin/env bash
# shellcheck shell=bash
# send-to-sftp lib — yad/zenity abstraction

if [[ -z "${DIALOG_TOOL:-}" ]]; then
  if command -v yad &>/dev/null; then
    DIALOG_TOOL="yad"
  elif command -v zenity &>/dev/null; then
    DIALOG_TOOL="zenity"
  else
    echo "Error: neither yad nor zenity found" >&2
    exit 1
  fi
else
  case "${DIALOG_TOOL}" in
    yad|zenity) ;;
    *)
      echo "Error: DIALOG_TOOL must be 'yad' or 'zenity', got '${DIALOG_TOOL}'" >&2
      exit 1
      ;;
  esac
fi

ui_pick_host() {
  local hosts=("$@")
  local selection

  case "${DIALOG_TOOL}" in
    yad)
      selection=$("${DIALOG_TOOL}" --list --column="Host" --text="Select SSH host" --height=400 "${hosts[@]}" 2>/dev/null)
      ;;
    zenity)
      selection=$("${DIALOG_TOOL}" --list --column="Host" --text="Select SSH host" --height=400 "${hosts[@]}" 2>/dev/null)
      ;;
  esac

  if [[ -z "${selection}" ]]; then
    return 1
  fi

  echo "${selection}"
  return 0
}

ui_pick_path() {
  local host="${1}"
  local start_dir="${2:-~}"
  local result

  case "${DIALOG_TOOL}" in
    yad)
      result=$("${DIALOG_TOOL}" --entry --text="Remote path on ${host}" --entry-text="${start_dir}" 2>/dev/null)
      ;;
    zenity)
      result=$("${DIALOG_TOOL}" --entry --text="Remote path on ${host}" --entry-text="${start_dir}" 2>/dev/null)
      ;;
  esac

  if [[ -z "${result}" ]]; then
    return 1
  fi

  echo "${result}"
  return 0
}

ui_confirm() {
  local msg="${1}"

  case "${DIALOG_TOOL}" in
    yad)
      "${DIALOG_TOOL}" --question --text="${msg}" 2>/dev/null
      ;;
    zenity)
      "${DIALOG_TOOL}" --question --text="${msg}" 2>/dev/null
      ;;
  esac
}

ui_error() {
  local msg="${1}"

  case "${DIALOG_TOOL}" in
    yad)
      "${DIALOG_TOOL}" --error --text="${msg}" --button="OK:0" 2>/dev/null
      ;;
    zenity)
      "${DIALOG_TOOL}" --error --text="${msg}" 2>/dev/null
      ;;
  esac

  return 0
}

ui_progress() {
  local msg="${1}"

  case "${DIALOG_TOOL}" in
    yad)
      "${DIALOG_TOOL}" --progress --text="${msg}" --percentage=0 --auto-close 2>/dev/null
      ;;
    zenity)
      "${DIALOG_TOOL}" --progress --text="${msg}" --percentage=0 --auto-close 2>/dev/null
      ;;
  esac
}
