#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

. "${GITROOT}"/env.sh
. ./define-certificates.sh

if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
  declare -a MINIONS=( $(multipass list | grep 'worker' | awk '{ print $1 }' ) )
  declare -a GRUS=( $(multipass list | grep 'controller' | awk '{ print $1 }' ) )
else
  declare -a MINIONS=( 'node-03' 'node-04' )
  declare -a GRUS=( 'node-02' )
fi

function check_gru_certs() {
  declare -a MISSING=()
  for cert in "${GRUS_CERTS[@]}"; do
    if [[ ! -f "${cert}" ]] ; then
      MISSING+=("${cert}")
    fi
  done
  if [[ ${#MISSING[@]} -ne 0 ]]; then
    msg_fatal "[-] Certs unmet. Please verify that the following are control plane certs missing: " "${MISSING[@]}"
  fi
}

function check_minion_certs() {
  declare -a MISSING=()
  for instance in "${MINIONS[@]}"; do
    declare -a MINIONS_CERTS=(
      './00-Certificate-Authority/kubelet-ca/kubelet-ca.pem' 
      "./10-kubelet-server/${instance}-server-key.pem"
      "./10-kubelet-server/${instance}-server.pem"
    )
    for cert in "${MINIONS_CERTS[@]}"; do
      if [[ ! -f "${cert}" ]] ; then
        MISSING+=("${cert}")
      fi
    done
  done
  if [[ ${#MISSING[@]} -ne 0 ]]; then
    msg_fatal "[-] Certs unmet. Please verify that the following are data plane(worker) certs missing: " "${MISSING[@]}"
  fi
}

check_gru_certs
check_minion_certs
