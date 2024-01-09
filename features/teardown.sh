#!/bin/bash

set -e
set -u

# Create a temp dir to do our work in.

TEMPDIR="$(mktemp -d)"

function cleanup() {
    rm -rf "$TEMPDIR"
}

trap cleanup exit

mkdir "$TEMPDIR/var" "$TEMPDIR/etc" "$TEMPDIR/run"

# Define functions that shadow the actual commands called by the script,
# that redirect all output to a file so we can check things.

function ipset () {
    echo "ipset" "$@"     >> "$TEMPDIR/out.txt"
}

function iptables () {
    echo "iptables " "$@" >> "$TEMPDIR/out.txt"
}

function ip6tables () {
    echo "ip6tables" "$@" >> "$TEMPDIR/out.txt"
}

# Source the microfw script to define the things we're going to test

RUNNING_IN_CI=true
VAR_DIR="$TEMPDIR/var"
RUN_DIR="$TEMPDIR/run"
ETC_DIR="$TEMPDIR/etc"
source src/microfw.sh

# Define test runner that prints results and exits on failure

function run_test() {
    FUNC="$1"
    rm -f "$TEMPDIR/out.txt" "$RUN_DIR/state.txt"
    echo -n "$FUNC... "
    if $FUNC; then
        echo "ok"
    else
        echo "failed"
        exit 1
    fi
}

# From here on out, we'll define scenarios

# Scenario: Nothing to tear down (note we do not create a state file). Nothing should happen.
function test_no_state() {
    tear_down
    [ ! -e "$TEMPDIR/out.txt" ]
}


# Scenario: No Docker, no mangle, just tear down a few zones.
function test_simple() {
    echo "ZONE asdf" >  "$RUN_DIR/state.txt"
    echo "ZONE ghjk" >> "$RUN_DIR/state.txt"
    tear_down
    [ -e "$TEMPDIR/out.txt" ]
    # We should detach from FORWARD, not DOCKER-USER (no Docker present)
    grep -q "iptables  -t filter -D FORWARD -j MFWFORWARD" "$TEMPDIR/out.txt"
    grep -q "ip6tables -t filter -D FORWARD -j MFWFORWARD" "$TEMPDIR/out.txt"
    # mangle tables should be left untouched
    grep -v -q mangle "$TEMPDIR/out.txt"
}


# Scenario: Let's add some Docker to the mix
function test_with_docker() {
    echo "HAVE-DOCKER" >  "$RUN_DIR/state.txt"
    echo "ZONE DOCKER" >> "$RUN_DIR/state.txt"
    echo "ZONE ghjk"   >> "$RUN_DIR/state.txt"
    tear_down
    [ -e "$TEMPDIR/out.txt" ]
    # We should detach IPv4 from DOCKER-USER now, but IPv6 still from FOWARD
    grep -q "iptables  -t filter -D DOCKER-USER -j MFWFORWARD" "$TEMPDIR/out.txt"
    grep -q "ip6tables -t filter -D FORWARD -j MFWFORWARD" "$TEMPDIR/out.txt"
    # mangle tables should be left untouched
    grep -v -q mangle "$TEMPDIR/out.txt"
}


# Scenario: Now let's try with mangle, but without Docker
function test_with_mangle() {
    echo "HAVE-MANGLE" >  "$RUN_DIR/state.txt"
    echo "ZONE asdf"   >> "$RUN_DIR/state.txt"
    echo "ZONE ghjk"   >> "$RUN_DIR/state.txt"
    tear_down
    [ -e "$TEMPDIR/out.txt" ]
    # We should detach from FORWARD, not DOCKER-USER (no Docker present)
    grep -q "iptables  -t filter -D FORWARD -j MFWFORWARD" "$TEMPDIR/out.txt"
    grep -q "ip6tables -t filter -D FORWARD -j MFWFORWARD" "$TEMPDIR/out.txt"
    # mangle tables should be detached and removed
    grep -q "iptables  -t mangle -D FORWARD -j MFWFORWARD" "$TEMPDIR/out.txt"
    grep -q "iptables  -t mangle -F asdf_fwd" "$TEMPDIR/out.txt"
}


# Scenario: Now let's try with mangle _and_ Docker
function test_with_docker_and_mangle() {
    echo "HAVE-DOCKER" >  "$RUN_DIR/state.txt"
    echo "HAVE-MANGLE" >> "$RUN_DIR/state.txt"
    echo "ZONE asdf"   >> "$RUN_DIR/state.txt"
    echo "ZONE ghjk"   >> "$RUN_DIR/state.txt"
    tear_down
    [ -e "$TEMPDIR/out.txt" ]
    # We should detach IPv4 from DOCKER-USER now, but IPv6 still from FOWARD
    grep -q "iptables  -t filter -D DOCKER-USER -j MFWFORWARD" "$TEMPDIR/out.txt"
    grep -q "ip6tables -t filter -D FORWARD -j MFWFORWARD" "$TEMPDIR/out.txt"
    # mangle tables should be also detached and removed
    grep -q "iptables  -t mangle -D FORWARD -j MFWFORWARD" "$TEMPDIR/out.txt"
    grep -q "iptables  -t mangle -F asdf_fwd" "$TEMPDIR/out.txt"
}


# Now run tests and see what happens

run_test test_no_state
run_test test_simple
run_test test_with_docker
run_test test_with_mangle
run_test test_with_docker_and_mangle
