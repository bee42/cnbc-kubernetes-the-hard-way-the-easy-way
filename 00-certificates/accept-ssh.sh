#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

. "${GITROOT}"/env.sh

if [[ "${MULTIPASS_ENABLED}" == 'off' ]] ; then
  declare -a NODES=( 'node-02' 'node-03' 'node-04' )
  for instance in "${NODES[@]}"; do
    msg_info "Accept ssh connection to host $instance"
    ssh -o StrictHostKeyChecking=no "$instance" "echo 'Connected!'" 2>/dev/null
  done
fi
