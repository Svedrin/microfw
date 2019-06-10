#!/bin/bash

set -e
set -u

WHERE=""

if [ -n "${1:-}" ]; then
    ./src/microfw.sh -n "$1" compile
    WHERE="-l $1"
fi

ansible-playbook -i nodes/inventory $WHERE ansible/playbook.yml
