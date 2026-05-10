#!/usr/bin/env bats
# Tests for lib/parse_ssh.sh

setup() {
    export SSH_CONFIG_FILE="${BATS_TEST_DIRNAME}/fixtures/ssh_config_sample"
    source "${BATS_TEST_DIRNAME}/../lib/parse_ssh.sh"
}

@test "list_hosts returns only non-wildcard hosts" {
    run list_hosts
    [[ "$status" -eq 0 ]]
    [[ "${lines[0]}" == "prod-web" ]]
    [[ "${lines[1]}" == "backup" ]]
    [[ "${lines[2]}" == "dev-box" ]]
}

@test "list_hosts does not return wildcard hosts" {
    run list_hosts
    [[ "$status" -eq 0 ]]
    [[ ! "${lines[*]}" =~ "staging-\*" ]]
    [[ ! "${lines[*]}" =~ "*\*" ]]
    [[ ! "${lines[*]}" =~ "\.example\.com" ]]
}

@test "list_hosts count is exactly 3" {
    run list_hosts
    [[ "$status" -eq 0 ]]
    [[ "${#lines[@]}" -eq 3 ]]
}

@test "host_info prod-web returns correct values" {
    run host_info "prod-web"
    [[ "$status" -eq 0 ]]
    local output
    output="${lines[*]}"
    [[ "$output" =~ "HostName=10.0.0.12" ]]
    [[ "$output" =~ "User=ubuntu" ]]
    [[ "$output" =~ "Port=2222" ]]
}

@test "host_info backup returns correct values" {
    run host_info "backup"
    [[ "$status" -eq 0 ]]
    local output
    output="${lines[*]}"
    [[ "$output" =~ "HostName=backup.example.com" ]]
    [[ "$output" =~ "User=deploy" ]]
}

@test "host_info unknown host handles gracefully" {
    run host_info "nonexistent-host"
    [[ "$status" -eq 0 ]]
}
