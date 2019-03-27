#!/bin/bash

set -e
set -u

WHERE=""

if [ -n "${1:-}" ]; then
    WHERE="-l $1"
fi

ansible-playbook -i ansible/hosts $WHERE ansible/playbook.yml
