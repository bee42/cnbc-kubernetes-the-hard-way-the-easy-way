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

# Wrapping it in quotes and adding spaces before and after 
# (" ${INSTANCE_GRU_CERT[@]} ") helps to avoid partial matches 
# (e.g., "an" matching "kubernetes-ca.pem").

function check_transfed_gru_certs() {
  declare -a MISSING=()
  for instance in "${GRUS[@]}"; do
    if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
      declare -a INSTANCE_GRU_CERT=( $(multipass exec $instance 'find . -type f -name "*.pem" | sort | sed "s|^./||"' ) )
    else
      declare -a INSTANCE_GRU_CERT=( $(ssh $instance 'find . -type f -name "*.pem" | sort' | sed "s|^./||") )
    fi
    for cert in "${GRUS_CERTS[@]}"; do
      cert_basename=("$(basename "$cert")")
      if [[ ! " ${INSTANCE_GRU_CERT[@]} " =~ " ${cert_basename} " ]] ; then
        MISSING+=("${cert}")
      fi
    done
  done
  if [[ ${#MISSING[@]} -ne 0 ]]; then
    msg_fatal "[-] Certs unmet. Please verify that the following are control plane certs missing: " "${MISSING[@]}"
  fi
}

function check_transfed_minion_certs() {
  declare -a MISSING=()
  for instance in "${MINIONS[@]}"; do
    declare -a MINIONS_CERTS=(
      './00-Certificate-Authority/kubelet-ca/kubelet-ca.pem' 
      "./10-kubelet-server/${instance}-server-key.pem"
      "./10-kubelet-server/${instance}-server.pem"
    )
    if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
      declare -a INSTANCE_MINION_CERT=( $(multipass exec $instance 'find . -type f -name "*.pem" | sort | sed "s|^./||"' ) )
    else
      declare -a INSTANCE_MINION_CERT=( $(ssh $instance 'find . -type f -name "*.pem" | sort | sed "s|^./||"' )  )
    fi
    for cert in "${MINIONS_CERTS[@]}"; do
      cert_basename=("$(basename "$cert")")
      if [[ ! " ${INSTANCE_MINION_CERT[@]} " =~ " ${cert_basename} " ]] ; then
        MISSING+=("${cert}")
      fi
    done
  done
  if [[ ${#MISSING[@]} -ne 0 ]]; then
    msg_fatal "[-] Certs unmet. Please verify that the following are data plane(worker) certs missing: " "${MISSING[@]}"
  fi
}

check_transfed_gru_certs
check_transfed_minion_certs
