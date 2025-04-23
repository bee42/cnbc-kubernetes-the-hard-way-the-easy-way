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

function check_gru_certs() {
  declare -a MISSING=()
  # Ensure dependencies are present
  for i in "${GRUS_CERTS[@]}"; do
    if [[ ! -f "${i}" ]] ; then
      MISSING+=("${i}")
    fi
  done
  if [[ ${#MISSING[@]} -ne 0 ]]; then
    msg_fatal "[-] Certs unmet. Please verify that the following are control plane certs missing: " "${MISSING[@]}"
  fi
}

function check_minion_certs() {
  declare -a MISSING=()
  # Ensure dependencies are present
  for i in "${MINIONS_CERTS[@]}"; do
    if [[ ! -f "${i}" ]] ; then
      MISSING+=("${i}")
    fi
  done
  if [[ ${#MISSING[@]} -ne 0 ]]; then
    msg_fatal "[-] Certs unmet. Please verify that the following are data plane(worker) certs missing: " "${MISSING[@]}"
  fi
}

check_gru_certs
check_minion_certs
