#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

COUNTRY="${1:-DE}"
CITY="${2:-Bochum}"
STATE="${3:-NRW}"

for instance in $(multipass list | grep 'worker' | awk '{ print $1 }'); do
cat > "${instance}"-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
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

INTERNAL_IP="$(multipass info "${instance}" | grep 'IPv4' | awk '{ print $2 }')"

cfssl gencert \
  -ca=../00-Certificate-Authority/ca.pem \
  -ca-key=../00-Certificate-Authority/ca-key.pem \
  -config=../00-Certificate-Authority/client-server-config.json \
  -hostname="${instance}","${INTERNAL_IP}" \
  -profile=kubernetes \
  "${instance}"-csr.json | cfssljson -bare "${instance}"
done
