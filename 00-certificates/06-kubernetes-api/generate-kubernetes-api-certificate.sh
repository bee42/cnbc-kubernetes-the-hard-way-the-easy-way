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
CLUSTER_DOAMIN="${4:-cluster.local}"

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
    COMPUTER_IPV4_ADDRESSES+=("${ip}")
  fi
done

IPV4_ADDRESSES=$(join_by ',' "${COMPUTER_IPV4_ADDRESSES[@]}")
KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.$(echo $CLUSTER_DOAMIN | sed "s/\./\n/g" | head -1 | tr -d "\n"),kubernetes.svc.${CLUSTER_DOMAIN}

echo  'Generating apiserver www server certificate'

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
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
  -hostname="${IPV4_ADDRESSES}",127.0.0.1,"${KUBE_API_CLUSTER_IP}","${KUBERNETES_HOSTNAMES}" \
  -profile=www \
  kubernetes-csr.json | cfssljson -bare kubernetes

echo  'Generating apiserver-kubelet-client certificate'

cat << EOF > apiserver-kubelet-client-csr.json
{
  "CN": "kube-apiserver-kubelet-client",
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
  -ca=../00-Certificate-Authority/kubernetes-ca.pem \
  -ca-key=../00-Certificate-Authority/kubernetes-ca-key.pem \
  -config=../00-Certificate-Authority/kubernetes-ca-config.json \
  -profile=client \
  apiserver-kubelet-client-csr.json | cfssljson -bare apiserver-kubelet-client

echo  'Generating client konnectivity-server certificate'

cat << EOF > konnectivity-server-csr.json
{
  "CN": "system:konnectivity-server",
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
  -ca=../00-Certificate-Authority/kubernetes-ca.pem \
  -ca-key=../00-Certificate-Authority/kubernetes-ca-key.pem \
  -config=../00-Certificate-Authority/kubernetes-ca-config.json \
  -profile=client \
  konnectivity-server-csr.json | cfssljson -bare  konnectivity-server
