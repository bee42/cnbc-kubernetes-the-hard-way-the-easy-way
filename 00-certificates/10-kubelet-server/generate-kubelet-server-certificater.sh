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

echo "Generating kubelet node server for ${instance} certificate"

if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
  INTERNAL_IP="$(multipass info "${instance}" | grep 'IPv4' | awk '{ print $2 }')"
else
  INTERNAL_IP=$(ssh "${instance}" "hostname -I | awk '{print \$1}'")
fi

cat > "${instance}"-server-csr.json <<EOF
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

# Generate the kubelet server certificate
# The certificate is signed by the Kubelet CA
# The certificate is used by the kubelet to authenticate apiserver as client
# Todo: check that this certs user for mtls cri?
cfssl gencert \
  -ca=../00-Certificate-Authority/kubelet-ca/kubelet-ca.pem \
  -ca-key=../00-Certificate-Authority/kubelet-ca/kubelet-ca-key.pem \
  -config=../00-Certificate-Authority/kubelet-ca/kubelet-ca-config.json \
  -profile=server \
  "${instance}"-server-csr.json | cfssljson -bare "${instance}-server"
done

echo  'Generating apiserver-kubelet-client certificate'

cat << EOF > apiserver-kubelet-client-csr.json
{
  "CN": "apiserver-kubelet-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${COUNTRY}",
      "L": "${CITY}",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "${STATE}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=../00-Certificate-Authority/kubelet-ca/kubelet-ca.pem \
  -ca-key=../00-Certificate-Authority/kubelet-ca/kubelet-ca-key.pem \
  -config=../00-Certificate-Authority/kubelet-ca/kubelet-ca-config.json \
  -profile=client \
  apiserver-kubelet-client-csr.json | cfssljson -bare apiserver-kubelet-client