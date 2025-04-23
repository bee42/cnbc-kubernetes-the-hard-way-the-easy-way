#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

COUNTRY="${1:-DE}"
CITY="${2:-Bochum}"
STATE="${3:-NRW}"

echo 'Generating kube-controller-manager client certificate'

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "${COUNTRY}",
      "L": "${CITY}",
      "O": "system:kube-controller-manager",
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
  -hostname="127.0.0.1" \
  -profile=client \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager
