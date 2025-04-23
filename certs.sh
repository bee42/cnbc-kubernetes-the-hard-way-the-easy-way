#!/usr/bin/env bash
source ./check_default.sh

msg_info 'Creating and distributing certificates'

cd 00-certificates/ || exit
bash distribute-certificates.sh "${COUNTRY}" "${CITY}" "${STATE}" ${CLUSTER_DOMAIN}
cd - || exit

