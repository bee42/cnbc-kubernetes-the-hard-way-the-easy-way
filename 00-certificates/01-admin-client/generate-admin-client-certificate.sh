#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'


COUNTRY="${1:-DE}"
CITY="${2:-Bochum}"
STATE="${3:-NRW}"

cat > admin-csr.json <<EOF
{
  "CN": "admin",
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
  -ca=../00-Certificate-Authority/ca.pem \
  -ca-key=../00-Certificate-Authority/ca-key.pem \
  -config=../00-Certificate-Authority/client-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin
