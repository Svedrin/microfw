#!/bin/bash

set -e
set -u

# Parse args

COMMAND="invalid"
ETC_DIR="/etc/microfw"
VAR_DIR="/var/lib/microfw"

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
            exit 0
            ;;

        -n|--node)
            ETC_DIR="nodes/$2"
            VAR_DIR=$ETC_DIR
            if [ ! -d "$ETC_DIR" ]; then
                echo >&2 "$ETC_DIR does not exist"
                exit 2
            fi
            shift
            ;;

        show|compile|apply)
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


function generate_tear_down() {
    echo '#!/bin/bash'
    echo 'set -e'
    echo 'set -u'

    # set sane defaults: Delete all rules and user-defined chains, then set the
    # policies to ACCEPT. we will add reject rules down the line, setting the
    # policy to ACCEPT means that the admin can get things to work using
    # iptables -F manually.
    # Then, delete all ipsets.

    echo iptables -F
    echo iptables -X

    echo iptables -t nat -F
    echo iptables -t nat -X

    echo iptables -P INPUT   ACCEPT
    echo iptables -P FORWARD ACCEPT
    echo iptables -P OUTPUT  ACCEPT


    echo ip6tables -F
    echo ip6tables -X

    echo ip6tables -t nat -F
    echo ip6tables -t nat -X

    echo ip6tables -P INPUT   ACCEPT
    echo ip6tables -P FORWARD ACCEPT
    echo ip6tables -P OUTPUT  ACCEPT


    echo ipset flush
    echo ipset destroy
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
    generate_tear_down > $VAR_DIR/tear_down.sh
    generate_setup     > $VAR_DIR/setup.sh
    chmod +x $VAR_DIR/tear_down.sh $VAR_DIR/setup.sh
}

function apply() {
    compile

    $VAR_DIR/tear_down.sh
    $VAR_DIR/setup.sh

    echo "REVERTING IN 30 SECONDS, HIT ^c"
    sleep 25
    echo "REVERTING IN 5 SECONDS, HIT ^c"
    sleep 5

    $VAR_DIR/tear_down.sh
}


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
esac
