#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

COUNTRY="${1:-DE}"
CITY="${2:-Bochum}"
STATE="${3:-NRW}"
VERSION_REGEX='([0-9]*)\.'

declare -a COMPUTER_IPV4_ADDRESSES=() COMPUTER_IP_ADDRESSES=()

while IFS= read -r ip; do
  if [[ -n ${ip} ]]; then
    COMPUTER_IP_ADDRESSES+=("${ip}")
  fi
done < <(get_ips)

# This works because we only have 1 controller
# logic will have to change if we have more than 1
while IFS= read -r ip; do
  if [[ -n ${ip} ]]; then
    COMPUTER_IP_ADDRESSES+=("${ip}")
  fi
done < <(multipass list | grep -E "${VERSION_REGEX}" | awk '{ print $3 }')

for ip in "${COMPUTER_IP_ADDRESSES[@]}"; do
  if grep -E "${VERSION_REGEX}" <<< "${ip}" > /dev/null; then
    COMPUTER_IPV4_ADDRESSES+=(\"${ip}\")
  fi
done

IPV4_ADDRESSES=$(join_by ',' "${COMPUTER_IPV4_ADDRESSES[@]}")

echo "Create the etcd server certificate ${IPV4_ADDRESSES}"

cat << EOF > etcd-server-csr.json
{
  "CN": "kube-etcd",
  "hosts": [
    ${IPV4_ADDRESSES},
    "localhost",
    "127.0.0.1"

  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

cfssl gencert \
  -ca=../00-Certificate-Authority/etcd-ca/etcd-ca.pem \
  -ca-key=../00-Certificate-Authority/etcd-ca/etcd-ca-key.pem \
  -config=../00-Certificate-Authority/etcd-ca/etcd-ca-config.json  \
  -profile=server \
  etcd-server-csr.json | cfssljson -bare etcd-server

echo 'Create the etcd peer certificate'

cat << EOF > etcd-peer-csr.json
{
  "CN": "kube-etcd-peer",
  "hosts": [
    ${IPV4_ADDRESSES},
    "localhost",
    "127.0.0.1"
  ],
  "key": {
    "algo": "rsa",
    "size": 2048
  }
}
EOF

cfssl gencert \
  -ca=../00-Certificate-Authority/etcd-ca/etcd-ca.pem \
  -ca-key=../00-Certificate-Authority/etcd-ca/etcd-ca-key.pem \
  -config=../00-Certificate-Authority/etcd-ca/etcd-ca-config.json  \
  -profile=peer \
  etcd-peer-csr.json | cfssljson -bare etcd-peer

echo 'Create the etcd healthcheck certificate'

cat << EOF > etcd-healthcheck-client-csr.json
{
  "CN": "kube-etcd-healthcheck-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "hosts": [
    "localhost",
    "127.0.0.1"
  ],
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
  -ca=../00-Certificate-Authority/etcd-ca/etcd-ca.pem \
  -ca-key=../00-Certificate-Authority/etcd-ca/etcd-ca-key.pem \
  -config=../00-Certificate-Authority/etcd-ca/etcd-ca-config.json  \
  -profile=client \
  etcd-healthcheck-client-csr.json | cfssljson -bare etcd-healthcheck-client

echo  'Generating apiserver etcd client certificate'

cat << EOF > apiserver-etcd-client-csr.json
{
  "CN": "kube-apiserver-etcd-client",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
    "hosts": [
    "localhost",
    "127.0.0.1"
  ],
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
  -ca=../00-Certificate-Authority/etcd-ca/etcd-ca.pem \
  -ca-key=../00-Certificate-Authority/etcd-ca/etcd-ca-key.pem \
  -config=../00-Certificate-Authority/etcd-ca/etcd-ca-config.json \
  -profile=client \
  apiserver-etcd-client-csr.json | cfssljson -bare apiserver-etcd-client
