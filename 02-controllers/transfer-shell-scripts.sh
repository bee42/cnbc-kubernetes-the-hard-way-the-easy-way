#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/env.sh

if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
  declare -a GRUS=( $(multipass list | grep 'controller' | awk '{ print $1 }' ) )
else
  declare -a GRUS=( 'node-02' )
fi

# TODO: only files from control plane services!
for instance in "${GRUS[@]}"; do
  for file in ./*/*.sh; do
    transfer_file "${file}" "${instance}"
  done
  for file in ./*/*.yaml; do
    transfer_file "${file}" "${instance}"
  done
done
