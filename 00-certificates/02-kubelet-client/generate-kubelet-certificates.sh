#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

. "${GITROOT}"/env.sh

set -euo pipefail
IFS=$'\n\t'

COUNTRY="${1:-DE}"
CITY="${2:-Bochum}"
STATE="${3:-NRW}"

if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
  declare -a MINIONS=( $(multipass list | grep 'worker' | awk '{ print $1 }' ) )
else
  declare -a MINIONS=( 'node-03' 'node-04' )
fi

for instance in "${MINIONS[@]}"; do

  echo "Generating kubelet node client and server certificate for ${instance}"

  if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
    INTERNAL_IP="$(multipass info "${instance}" | grep 'IPv4' | awk '{ print $2 }')"
  else
    INTERNAL_IP=$(ssh "${instance}" "hostname -I | awk '{print \$1}'")
  fi
  cat > "${instance}"-csr.json <<EOF
  {
    "CN": "system:node:${instance}",
    "key": {
      "algo": "rsa",
      "size": 2048
    },
    "hosts": [
      "${instance}",
      "${INTERNAL_IP}"
    ],
    "names": [
      {
        "C": "${COUNTRY}",
        "L": "${CITY}",
        "O": "system:nodes",
        "OU": "Kubernetes The Hard Way",
        "ST": "${STATE}"
      }
    ]
  }
  EOF

  # Generate the kubelet client and server certificate
  # The certificate is signed by the Kubernetes CA
  # The certificate is used by the kubelet to authenticate to the Kubernetes API server
  cfssl gencert \
    -ca=../00-Certificate-Authority/kubernetes-ca.pem \
    -ca-key=../00-Certificate-Authority/kubernetes-ca-key.pem \
    -config=../00-Certificate-Authority/kubernetes-ca-config.json \
    -profile=worker \
    "${instance}"-csr.json | cfssljson -bare "${instance}"

done
