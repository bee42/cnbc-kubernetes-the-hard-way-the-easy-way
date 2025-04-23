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
  declare -a GRUS=( $(multipass list | grep 'controller' | awk '{ print $1 }' ) )
else
  declare -a MINIONS=( 'node-03' 'node-04' )
  declare -a GRUS=( 'node-02' )
fi

. ./define-certificates.sh

for instance in "${MINIONS[@]}"; do
  declare -a MINIONS_CERTS=(
    './00-Certificate-Authority/kubernetes-ca.pem' 
    "./02-kubelet-client/${instance}-key.pem"
    "./02-kubelet-client/${instance}.pem"
  )
  for file in "${MINIONS_CERTS[@]}"; do
    transfer_file "${file}" "${instance}"
  done
done

for instance in "${GRUS[@]}"; do
  for file in "${GRUS_CERTS[@]}"; do
    transfer_file "${file}" "${instance}"
  done
done
