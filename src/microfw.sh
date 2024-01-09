#!/bin/bash

set -e
set -u

# Parse args
if [ -z "${RUNNING_IN_CI:-}" ]; then
    COMMAND="invalid"
    ETC_DIR="/etc/microfw"
    VAR_DIR="/var/lib/microfw"
    RUN_DIR="/run/microfw"

    while [ -n "${1:-}" ]; do
        case "$1" in
            -h|--help)
                echo "Usage: $0 [-n <node>] <command>"
                echo
                echo "Options:"
                echo " -h --help     This help text"
                echo " -n --node     Read config from nodes/<node> subdir instead of /etc/microfw"
                echo
                echo "Commands:"
                echo " show          Generate and show setup.sh, but do not write it to disk"
                echo " compile       Update tear_down.sh and setup.sh"
                echo " apply         compile, run setup, prompt for aliveness, run teardown on timeout"
                echo " apply_bootup  compile, run setup"
                echo "               Note: Be sure you have applied the last changes. They will be active"
                echo "                     after a reboot and you won't get a chance to revert them"
                echo "                     in case you locked yourself out. Further this function is only meant"
                echo "                     to be called from systemd service."
                echo " tear_down     tear down any existing rules"
                exit 0
                ;;

            -n|--node)
                ETC_DIR="nodes/$2"
                VAR_DIR="$ETC_DIR"
                if [ ! -d "$ETC_DIR" ]; then
                    echo >&2 "$ETC_DIR does not exist"
                    exit 2
                fi
                shift
                ;;

            show|compile|apply|apply_bootup|tear_down)
                COMMAND="$1"
                ;;

            *)
                echo "Unknown option $1, see --help"
                exit 3
        esac
        shift
    done

    if [ "$COMMAND" = "invalid" ]; then
        echo "Need a command, see --help"
        exit 3
    fi
fi

function tear_down() {
    if [ ! -e "$RUN_DIR/state.txt" ]; then
        # Already torn down -> nothing to do
        return
    fi

    # We're not sure which state we're actually in, so we need to accept
    # that any one of our iptables commands can fail because the things
    # they're trying to uninstall have already been removed.
    set +e

    # First let's find out if docker and mangle are present
    HAVE_DOCKER="$(grep -q "^HAVE-DOCKER$" "$RUN_DIR/state.txt" && echo "true" || echo "false")"
    HAVE_MANGLE="$(grep -q "^HAVE-MANGLE$" "$RUN_DIR/state.txt" && echo "true" || echo "false")"

    # Little helper function that makes it easier to run the same command for
    # both iptables and ip6tables
    function ip+6tables {
        iptables  "$@"
        ip6tables "$@"
    }

    # Now let's actually shut down the firewall
    # Detach our input chains from the main iptables chains
    ip+6tables -t filter -D INPUT       -j MFWINPUT
    if [ "$HAVE_DOCKER" = "true" ]; then
        iptables   -t filter -D DOCKER-USER -j MFWFORWARD
        ip6tables  -t filter -D FORWARD     -j MFWFORWARD
    else
        ip+6tables -t filter -D FORWARD     -j MFWFORWARD
    fi
    if [ "$HAVE_MANGLE" = "true" ]; then
        ip+6tables -t mangle -D FORWARD     -j MFWFORWARD
    fi
    ip+6tables -t nat    -D PREROUTING  -j MFWPREROUTING
    ip+6tables -t nat    -D POSTROUTING -j MFWPOSTROUTING

    # Flush chains so the zone-specific chains are free after flush
    for chain in accept drop reject MFWINPUT MFWFORWARD; do
        ip+6tables -t filter -F "$chain"
    done
    if [ "$HAVE_MANGLE" = "true" ]; then
        ip+6tables -t mangle -F MFWFORWARD
    fi
    for chain in MFWPREROUTING MFWPOSTROUTING; do
        ip+6tables -t nat    -F "$chain"
    done

    # Flush and drop zone-specific chains
    grep "^ZONE " "$RUN_DIR/state.txt" | while read command zone; do
        ip+6tables -t filter -F "${zone}_inp"
        ip+6tables -t filter -X "${zone}_inp"
        ip+6tables -t filter -F "${zone}_fwd"
        ip+6tables -t filter -X "${zone}_fwd"
        if [ "$HAVE_MANGLE" = "true" ]; then
            ip+6tables -t mangle -F "${zone}_fwd"
            ip+6tables -t mangle -X "${zone}_fwd"
        fi
    done

    # The chains that we flushed above, now we drop
    for chain in accept drop reject MFWINPUT MFWFORWARD; do
        ip+6tables -t filter -X "$chain"
    done
    if [ "$HAVE_MANGLE" = "true" ]; then
        ip+6tables -t mangle -X MFWFORWARD
    fi
    for chain in MFWPREROUTING MFWPOSTROUTING; do
        ip+6tables -t nat    -X "$chain"
    done

    # Get rid of ipsets
    ipset flush
    ipset destroy

    rm "$RUN_DIR/state.txt"
    set -e
}

function generate_setup() {
    if [ -e "/usr/local/lib/microfw/generate_setup.py" ]; then
        /usr/local/lib/microfw/generate_setup.py "$ETC_DIR"
    else
        src/generate_setup.py "$ETC_DIR"
    fi
}

function compile() {
    mkdir -p $VAR_DIR
    generate_setup     > $VAR_DIR/setup.sh
    chmod +x $VAR_DIR/setup.sh
}

function apply() {
    compile

    # Do we need geoip?
    if grep -q -e '-m geoip' $VAR_DIR/setup.sh; then
        if [ ! -e /usr/libexec/xtables-addons/xt_geoip_dl ]; then
            echo >&2 "GeoIP modules are missing, cannot apply rules! To fix this, run:"
            echo >&2 "    apt install xtables-addons-common libtext-csv-xs-perl"
            exit 1
        fi
        # Check if we have an outdated index (older than 15min) or none at all
        if [ ! -e $VAR_DIR/dbip-country-lite.csv ] || \
           [ -n "$(find $VAR_DIR/dbip-country-lite.csv -cmin +60)" ] || \
           [ -z "$(find /usr/share/xt_geoip/ -mindepth 1)" ]
        then
            cd $VAR_DIR
            /usr/libexec/xtables-addons/xt_geoip_dl
            /usr/libexec/xtables-addons/xt_geoip_build -D /usr/share/xt_geoip/ dbip-country-lite.csv
        fi
    fi

    tear_down
    $VAR_DIR/setup.sh

    echo "REVERTING IN 30 SECONDS, HIT ^c"
    sleep 25
    echo "REVERTING IN 5 SECONDS, HIT ^c"
    sleep 5

    tear_down
}


function apply_bootup() {

    rm -f $VAR_DIR/setup.sh

    compile
    $VAR_DIR/setup.sh

}

if [ -z "${RUNNING_IN_CI:-}" ]; then
    case "$COMMAND" in
        show)
            generate_setup
            ;;
        compile)
            compile
            ;;
        apply)
            apply
            ;;
        apply_bootup)
            apply_bootup
            ;;
        tear_down)
            tear_down
            ;;
    esac
fi
