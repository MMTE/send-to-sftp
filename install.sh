#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DETECTED_FMS=()

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { printf "${GREEN}[*] %s${NC}\n" "$*"; }
warn()  { printf "${YELLOW}[!] %s${NC}\n" "$*"; }
error() { printf "${RED}[!] %s${NC}\n" "$*" >&2; }

usage() {
    cat <<'EOF'
Usage: install.sh [OPTIONS]

Install or uninstall send-to-sftp with file-manager integrations.

Options:
    --user        Install to user directories (default)
    --system      Install to system directories (requires sudo)
    --uninstall   Remove send-to-sftp and all integrations
    --help        Show this help message
EOF
}

# ─── Defaults ────────────────────────────────────────────────
MODE="user"
UNINSTALL=false

# ─── Parse flags ─────────────────────────────────────────────
while (( $# > 0 )); do
    case "$1" in
        --user)      MODE="user"; shift ;;
        --system)    MODE="system"; shift ;;
        --uninstall) UNINSTALL=true; shift ;;
        --help|-h)   usage; exit 0 ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# ─── Set paths based on mode ────────────────────────────────
if [[ "$MODE" == "system" ]]; then
    if (( EUID != 0 )); then
        error "System install requires root privileges. Use sudo."
        exit 1
    fi
    PREFIX="/usr/local"
    CAJA_SCRIPTS_DIR="${PREFIX}/config/caja/scripts"
else
    PREFIX="${HOME}/.local"
    CAJA_SCRIPTS_DIR="${HOME}/.config/caja/scripts"
fi

BIN_DIR="${PREFIX}/bin"
SHARE_DIR="${PREFIX}/share"
BIN_PATH="${BIN_DIR}/send-to-sftp"
LIB_DIR="${SHARE_DIR}/send-to-sftp"
THUNAR_UCA="${HOME}/.config/Thunar/uca.xml"
THUNAR_UID="send-to-sftp-0"

# ─── File manager detection ─────────────────────────────────
detect_file_managers() {
    DETECTED_FMS=()
    if command -v nautilus &>/dev/null; then
        DETECTED_FMS+=("nautilus")
    fi
    if command -v nemo &>/dev/null; then
        DETECTED_FMS+=("nemo")
    fi
    if command -v caja &>/dev/null; then
        DETECTED_FMS+=("caja")
    fi
    if command -v thunar &>/dev/null; then
        DETECTED_FMS+=("thunar")
    fi
}

# ─── Create directories ─────────────────────────────────────
create_dirs() {
    mkdir -p "${BIN_DIR}" "${LIB_DIR}"
    mkdir -p "${SHARE_DIR}/nautilus/scripts"
    mkdir -p "${SHARE_DIR}/nemo/scripts"
    mkdir -p "${CAJA_SCRIPTS_DIR}"
    mkdir -p "$(dirname "${THUNAR_UCA}")"
}

# ─── Install binary ─────────────────────────────────────────
install_binary() {
    cp "${SCRIPT_DIR}/bin/send-to-sftp" "${BIN_PATH}"
    chmod +x "${BIN_PATH}"
    info "Installed binary → ${BIN_PATH}"
}

# ─── Install libraries ──────────────────────────────────────
install_libs() {
    cp "${SCRIPT_DIR}/lib/"*.sh "${LIB_DIR}/"
    info "Installed libraries → ${LIB_DIR}/"
}

# ─── Install file manager wrappers ──────────────────────────
install_wrappers() {
    local fm dest
    for fm in "${DETECTED_FMS[@]}"; do
        case "$fm" in
            nautilus)
                dest="${SHARE_DIR}/nautilus/scripts/Send to SFTP"
                if [[ "$MODE" == "system" ]]; then
                    sed "s|exec \"\${HOME}/.local/bin/send-to-sftp\"|exec \"${BIN_PATH}\"|" \
                        "${SCRIPT_DIR}/integrations/nautilus/Send to SFTP" > "$dest"
                else
                    cp "${SCRIPT_DIR}/integrations/nautilus/Send to SFTP" "$dest"
                fi
                chmod +x "$dest"
                info "Installed Nautilus script → ${dest}"
                ;;
            nemo)
                dest="${SHARE_DIR}/nemo/scripts/Send to SFTP"
                if [[ "$MODE" == "system" ]]; then
                    sed "s|exec \"\${HOME}/.local/bin/send-to-sftp\"|exec \"${BIN_PATH}\"|" \
                        "${SCRIPT_DIR}/integrations/nemo/Send to SFTP" > "$dest"
                else
                    cp "${SCRIPT_DIR}/integrations/nemo/Send to SFTP" "$dest"
                fi
                chmod +x "$dest"
                info "Installed Nemo script → ${dest}"
                ;;
            caja)
                dest="${CAJA_SCRIPTS_DIR}/Send to SFTP"
                if [[ "$MODE" == "system" ]]; then
                    sed "s|exec \"\${HOME}/.local/bin/send-to-sftp\"|exec \"${BIN_PATH}\"|" \
                        "${SCRIPT_DIR}/integrations/caja/Send to SFTP" > "$dest"
                else
                    cp "${SCRIPT_DIR}/integrations/caja/Send to SFTP" "$dest"
                fi
                chmod +x "$dest"
                info "Installed Caja script → ${dest}"
                ;;
            thunar)
                install_thunar_action
                ;;
        esac
    done
}

# ─── Thunar uca.xml handling ───────────────────────────────
install_thunar_action() {
    local snippet="${SCRIPT_DIR}/integrations/thunar/uca.xml.snippet"
    if [[ ! -f "$snippet" ]]; then
        warn "Thunar snippet not found: ${snippet}"
        return 0
    fi

    if [[ -f "${THUNAR_UCA}" ]]; then
        if grep -q "${THUNAR_UID}" "${THUNAR_UCA}" 2>/dev/null; then
            info "Thunar action already present in ${THUNAR_UCA}"
            return 0
        fi

        local tmp_file
        tmp_file="$(mktemp)"
        while IFS= read -r line || [[ -n "$line" ]]; do
            if [[ "$line" == "</actions>" ]]; then
                grep -v '<?xml' "$snippet" >> "$tmp_file"
            fi
            printf '%s\n' "$line" >> "$tmp_file"
        done < "${THUNAR_UCA}"
        mv "$tmp_file" "${THUNAR_UCA}"
        info "Added Thunar action → ${THUNAR_UCA}"
    else
        {
            echo '<?xml version="1.0" encoding="UTF-8"?>'
            echo '<actions>'
            grep -v '<?xml' "$snippet"
            echo '</actions>'
        } > "${THUNAR_UCA}"
        info "Created ${THUNAR_UCA} with Send to SFTP action"
    fi
}

# ─── Check dependencies ─────────────────────────────────────
check_dependencies() {
    local missing=()
    local optional_missing=()

    if ! command -v rsync &>/dev/null; then
        missing+=("rsync")
    fi
    if ! command -v ssh &>/dev/null; then
        missing+=("ssh")
    fi
    if ! command -v yad &>/dev/null && ! command -v zenity &>/dev/null; then
        missing+=("yad")
    fi
    if ! command -v notify-send &>/dev/null; then
        optional_missing+=("libnotify-bin")
    fi

    if (( ${#missing[@]} > 0 )); then
        error "Missing required dependencies: ${missing[*]}"
        error "  sudo apt install ${missing[*]}"
    fi

    if (( ${#optional_missing[@]} > 0 )); then
        warn "Missing optional dependencies: ${optional_missing[*]}"
        warn "  sudo apt install ${optional_missing[*]}"
    fi
}

# ─── Restart file managers ──────────────────────────────────
restart_file_managers() {
    local fm
    for fm in "${DETECTED_FMS[@]}"; do
        case "$fm" in
            nautilus) nautilus -q 2>/dev/null || true ;;
            nemo)     nemo --quit 2>/dev/null || true ;;
            caja)     caja --quit 2>/dev/null || true ;;
            thunar)   thunar -q 2>/dev/null || true ;;
        esac
    done
}

# ─── Remove Thunar action ───────────────────────────────────
remove_thunar_action() {
    if [[ ! -f "${THUNAR_UCA}" ]]; then
        return 0
    fi
    if ! grep -q "${THUNAR_UID}" "${THUNAR_UCA}" 2>/dev/null; then
        return 0
    fi

    local tmp_file
    tmp_file="$(mktemp)"
    awk -v uid="${THUNAR_UID}" '
        /<action>/ { in_action=1; buf=$0 "\n"; next }
        in_action {
            buf = buf $0 "\n"
            if (/<\/action>/) {
                in_action = 0
                if (buf !~ uid) {
                    printf "%s", buf
                }
            }
            next
        }
        { print }
    ' "${THUNAR_UCA}" > "$tmp_file"
    mv "$tmp_file" "${THUNAR_UCA}"
    info "Removed Thunar action from ${THUNAR_UCA}"
}

# ─── Install ────────────────────────────────────────────────
do_install() {
    echo ""
    info "Installing send-to-sftp (${MODE} mode)..."

    detect_file_managers
    create_dirs
    install_binary
    install_libs

    if (( ${#DETECTED_FMS[@]} > 0 )); then
        install_wrappers
    else
        warn "No supported file managers detected"
    fi

    check_dependencies
    restart_file_managers

    echo ""
    info "Installation complete!"
    info "  Binary:    ${BIN_PATH}"
    info "  Libraries: ${LIB_DIR}/"
    if (( ${#DETECTED_FMS[@]} > 0 )); then
        info "  Integrations: ${DETECTED_FMS[*]}"
    fi
    echo ""
}

# ─── Uninstall ──────────────────────────────────────────────
do_uninstall() {
    echo ""
    info "Uninstalling send-to-sftp..."

    detect_file_managers

    if [[ -f "${BIN_PATH}" ]]; then
        rm -f "${BIN_PATH}"
        info "Removed ${BIN_PATH}"
    fi

    if [[ -d "${LIB_DIR}" ]]; then
        rm -rf "${LIB_DIR}"
        info "Removed ${LIB_DIR}/"
    fi

    local wrapper
    wrapper="${SHARE_DIR}/nautilus/scripts/Send to SFTP"
    if [[ -f "$wrapper" ]]; then
        rm -f "$wrapper"
        info "Removed ${wrapper}"
    fi

    wrapper="${SHARE_DIR}/nemo/scripts/Send to SFTP"
    if [[ -f "$wrapper" ]]; then
        rm -f "$wrapper"
        info "Removed ${wrapper}"
    fi

    wrapper="${CAJA_SCRIPTS_DIR}/Send to SFTP"
    if [[ -f "$wrapper" ]]; then
        rm -f "$wrapper"
        info "Removed ${wrapper}"
    fi

    remove_thunar_action
    restart_file_managers

    echo ""
    info "Uninstallation complete!"
    echo ""
}

# ─── Main ────────────────────────────────────────────────────
if [[ "${UNINSTALL}" == true ]]; then
    do_uninstall
else
    do_install
fi
