#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

COUNTRY="${1:-DE}"
CITY="${2:-Bochum}"
STATE="${3:-NRW}"

for instance in $(multipass list | grep 'worker' | awk '{ print $1 }'); do

echo "Generating kubelet node client and server certificate for ${instance}"

INTERNAL_IP="$(multipass info "${instance}" | grep 'IPv4' | awk '{ print $2 }')"

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
