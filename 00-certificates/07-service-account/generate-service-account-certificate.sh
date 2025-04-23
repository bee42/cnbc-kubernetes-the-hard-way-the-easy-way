#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

COUNTRY="${1:-DE}"
CITY="${2:-Bochum}"
STATE="${3:-NRW}"

echo 'Generating service account certificate'

cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${COUNTRY}",
      "L": "${CITY}",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "${STATE}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=../00-Certificate-Authority/kubernetes-ca.pem \
  -ca-key=../00-Certificate-Authority/kubernetes-ca-key.pem \
  -config=../00-Certificate-Authority/kubernetes-ca-config.json \
  -profile=client \
  service-account-csr.json | cfssljson -bare service-account
