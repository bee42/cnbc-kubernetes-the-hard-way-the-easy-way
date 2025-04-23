#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

. "${GITROOT}"/env.sh

msg_info 'Creating and distributing certificates'

cd 00-certificates/ || exit
bash distribute-certificates.sh "${COUNTRY}" "${CITY}" "${STATE}" ${CLUSTER_DOMAIN}
cd - || exit

