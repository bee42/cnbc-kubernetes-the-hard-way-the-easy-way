#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

COUNTRY="${1:-DE}"
CITY="${2:-Bochum}"
STATE="${3:-NRW}"

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${COUNTRY}",
      "L": "${CITY}",
      "O": "system:kube-scheduler",
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
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler
