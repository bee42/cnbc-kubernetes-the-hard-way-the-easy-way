#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

COUNTRY="${1:-DE}"
CITY="${2:-Bochum}"
STATE="${3:-NRW}"
CLUSTER_DOAMIN="${4:-cluster.local}"

for file in ./*/*.sh; do
  cd "$(dirname ./"${file}")" || exit
  bash "${file##*/}" $COUNTRY "$CITY" "$STATE" $CLUSTER_DOAMIN
  if [[ $? -ne 0 ]]; then
    msg_fatal "[-] Error generating certificate in ${file})"
  fi
  cd - || exit
done

