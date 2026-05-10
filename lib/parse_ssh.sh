#!/usr/bin/env bash
# shellcheck shell=bash
# send-to-sftp lib — parse ~/.ssh/config → host list

_ssh_config_file="${SSH_CONFIG_FILE:-"${HOME}/.ssh/config"}"

_is_wildcard_host() {
    local patterns="$1"
    local -a pats
    local old_nullglob
    old_nullglob=$(shopt -p nullglob)
    shopt -u nullglob
    IFS=' ' read -r -a pats <<< "$patterns"
    eval "$old_nullglob"
    local pattern
    for pattern in "${pats[@]}"; do
        case "$pattern" in
            *\**|*\?*) return 0 ;;
        esac
    done
    return 1
}

list_hosts() {
    local config_file="${SSH_CONFIG_FILE:-"${HOME}/.ssh/config"}"
    if [[ ! -r "$config_file" ]]; then
        echo "Error: cannot read ${config_file}" >&2
        return 1
    fi
    while IFS= read -r line || [[ -n "$line" ]]; do
        local trimmed
        trimmed="${line#"${line%%[![:space:]]*}"}"
        trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
        [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue
        if [[ "$trimmed" =~ ^[Ii]nclude[[:space:]] ]]; then
            local include_path
            include_path="${trimmed#Include}"
            include_path="${include_path#"${include_path%%[![:space:]]*}"}"
            echo "Note: Include directive found: ${include_path}" >&2
            continue
        fi
        if [[ "$trimmed" =~ ^[Hh]ost[[:space:]] ]]; then
            local host_patterns
            host_patterns="${trimmed#Host}"
            host_patterns="${host_patterns#"${host_patterns%%[![:space:]]*}"}"
            if ! _is_wildcard_host "$host_patterns"; then
                local first_pattern
                read -r first_pattern <<< "$host_patterns"
                echo "$first_pattern"
            fi
        fi
    done < "$config_file"
}

host_info() {
    local alias="$1"
    if [[ -z "$alias" ]]; then
        echo "Error: host_info requires an alias argument" >&2
        return 1
    fi
    local use_ssh_g=true
    if [[ -n "${SSH_CONFIG_FILE:-}" ]] && [[ "$SSH_CONFIG_FILE" != "${HOME}/.ssh/config" ]]; then
        use_ssh_g=false
    fi

    if [[ "$use_ssh_g" == true ]] && command -v ssh &>/dev/null; then
        local line key value
        while IFS= read -r line; do
            local lower_line
            lower_line="${line,,}"
            case "$lower_line" in
                hostname\ *)
                    key="HostName"
                    value="${line#hostname }"
                    printf '%s=%s\n' "$key" "$value"
                    ;;
                user\ *)
                    key="User"
                    value="${line#user }"
                    printf '%s=%s\n' "$key" "$value"
                    ;;
                port\ *)
                    key="Port"
                    value="${line#port }"
                    printf '%s=%s\n' "$key" "$value"
                    ;;
                identityfile\ *)
                    key="IdentityFile"
                    value="${line#identityfile }"
                    printf '%s=%s\n' "$key" "$value"
                    ;;
            esac
        done < <(ssh -G "$alias" 2>/dev/null)
    else
        local config_file="${SSH_CONFIG_FILE:-"${HOME}/.ssh/config"}"
        if [[ ! -r "$config_file" ]]; then
            echo "Error: cannot read ${config_file}" >&2
            return 1
        fi
        local current_hosts=""
        local in_block=false
        while IFS= read -r line || [[ -n "$line" ]]; do
            local trimmed
            trimmed="${line#"${line%%[![:space:]]*}"}"
            trimmed="${trimmed%"${trimmed##*[![:space:]]}"}"
            [[ -z "$trimmed" || "$trimmed" == \#* ]] && continue
            if [[ "$trimmed" =~ ^[Hh]ost[[:space:]] ]]; then
                local host_patterns
                host_patterns="${trimmed#Host}"
                host_patterns="${host_patterns#"${host_patterns%%[![:space:]]*}"}"
                current_hosts="$host_patterns"
                in_block=true
                continue
            fi
            if [[ "$in_block" == true ]]; then
                local found=false
                local pat
                for pat in $current_hosts; do
                    if [[ "$pat" == "$alias" ]]; then
                        found=true
                        break
                    fi
                done
                if [[ "$found" == false ]]; then
                    in_block=false
                    continue
                fi
            fi
            if [[ "$in_block" == true ]]; then
                local lhs rhs
                read -r lhs rhs <<< "$trimmed"
                case "$lhs" in
                    HostName)       printf 'HostName=%s\n' "$rhs" ;;
                    User)           printf 'User=%s\n' "$rhs" ;;
                    Port)           printf 'Port=%s\n' "$rhs" ;;
                    IdentityFile)   printf 'IdentityFile=%s\n' "$rhs" ;;
                esac
            fi
        done < "$config_file"
    fi
}
