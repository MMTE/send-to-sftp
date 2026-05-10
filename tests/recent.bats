#!/usr/bin/env bats
# Tests for lib/recent.sh

setup() {
    # Use a temp directory for test data
    export TEST_DIR=$(mktemp -d)
    export XDG_CONFIG_HOME="${TEST_DIR}/.config"
    export RECENT_FILE="${XDG_CONFIG_HOME}/send-to-sftp/recent"
    export RECENT_LIMIT=5
    source "${BATS_TEST_DIRNAME}/../lib/recent.sh"
}

teardown() {
    rm -rf "${TEST_DIR:-}"
}

@test "recent_list returns empty when no file exists" {
    run recent_list
    [[ "$status" -eq 0 ]]
    [[ -z "$output" ]]
}

@test "recent_add creates file and adds entry" {
    recent_add "prod-web" "/var/www"
    run recent_list
    [[ "$status" -eq 0 ]]
    [[ "$output" == "prod-web:/var/www" ]]
}

@test "recent_list returns newest first" {
    recent_add "host-a" "/path/a"
    recent_add "host-b" "/path/b"
    run recent_list
    [[ "$status" -eq 0 ]]
    [[ "${lines[0]}" == "host-b:/path/b" ]]
    [[ "${lines[1]}" == "host-a:/path/a" ]]
}

@test "recent_add deduplicates" {
    recent_add "host-a" "/path/a"
    recent_add "host-b" "/path/b"
    recent_add "host-a" "/path/a"
    run recent_list
    [[ "$status" -eq 0 ]]
    # After dedup, host-a:/path/a should appear once, at the top (newest)
    [[ "${#lines[@]}" -eq 2 ]]
    [[ "${lines[0]}" == "host-a:/path/a" ]]
    [[ "${lines[1]}" == "host-b:/path/b" ]]
}

@test "recent_list respects RECENT_LIMIT" {
    RECENT_LIMIT=3
    recent_add "h1" "/p1"
    recent_add "h2" "/p2"
    recent_add "h3" "/p3"
    recent_add "h4" "/p4"
    recent_add "h5" "/p5"
    run recent_list
    [[ "$status" -eq 0 ]]
    [[ "${#lines[@]}" -eq 3 ]]
    # Newest 3 should be h5, h4, h3
    [[ "${lines[0]}" == "h5:/p5" ]]
    [[ "${lines[1]}" == "h4:/p4" ]]
    [[ "${lines[2]}" == "h3:/p3" ]]
}

@test "recent_add handles path with spaces" {
    recent_add "my-host" "/path/with spaces/docs"
    run recent_list
    [[ "$status" -eq 0 ]]
    [[ "$output" == "my-host:/path/with spaces/docs" ]]
}
