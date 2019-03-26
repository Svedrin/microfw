#!/bin/bash

set -e
set -u

ansible-playbook -i ansible/hosts ansible/playbook.yml
