#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

COUNTRY="${1:-DE}"
CITY="${2:-Bochum}"
STATE="${3:-NRW}"

echo 'Generating front-proxy-client certificate'

cat > front-proxy-client-csr.json <<EOF
{
  "CN": "front-proxy-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${COUNTRY}",
      "L": "${CITY}",
      "O": "front-proxy-client",
      "OU": "Kubernetes The Hard Way",
      "ST": "${STATE}"
    }
  ]
}
EOF

cfssl gencert \
  -ca=../00-Certificate-Authority/kubernetes-front-proxy-ca.pem \
  -ca-key=../00-Certificate-Authority/kubernetes-front-proxy-ca-key.pem \
  -config=../00-Certificate-Authority/kubernetes-front-proxy-ca-config.json  \
  -profile=client \
  front-proxy-client-csr.json | cfssljson -bare front-proxy-client
