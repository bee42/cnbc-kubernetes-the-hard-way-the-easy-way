#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode
. "${GITROOT}"/env.sh

if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
  declare -a MINIONS=( $(multipass list | grep 'worker' | awk '{ print $1 }' ) )
else
  declare -a MINIONS=( 'node-03' 'node-04' )
fi

for instance in "$MINIONS[l]}""; do
  for file in ./*/*.sh; do
    transfer_file "${file}" "${instance}"
  done
done
