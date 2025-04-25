#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/env.sh

COUNTRY="${1:-DE}"
CITY="${2:-Bochum}"
STATE="${3:-NRW}"
CLUSTER_DOAMIN="${4:-cluster.local}"

VERSION_REGEX='([0-9]*)\.'
declare -a COMPUTER_IPV4_ADDRESSES=() COMPUTER_IP_ADDRESSES=()

if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then

  # this is need to address the cluster from outside with bastion host IP!
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
else
  # use this for kubelet and apiserver
  # to get the IP address of the other nodes
  # in the cluster
  declare -a INSTANCE=( 'node-02' 'node-03' 'node-04' )

  for instance in "${INSTANCE[@]}"; do
    COMPUTER_IP_ADDRESSES+=$(ssh "${instance}" "hostname -I | awk '{print \$1}'")
  done
fi

for ip in "${COMPUTER_IP_ADDRESSES[@]}"; do
  if grep -E "${VERSION_REGEX}" <<< "${ip}" > /dev/null; then
    COMPUTER_IPV4_ADDRESSES+=("${ip}")
  fi
done

IPV4_ADDRESSES=$(join_by ',' "${COMPUTER_IPV4_ADDRESSES[@]}")

KUBERNETES_HOSTNAMES=kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.$(echo $CLUSTER_DOAMIN | sed "s/\./\n/g" | head -1 | tr -d "\n"),kubernetes.svc.${CLUSTER_DOMAIN}

echo  'Generating apiserver and kubelet www server certificate'

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

# Add external IP/Name of iximiuz instance?
# Add internal cluster ip: KUBE_API_CLUSTER_IP
cfssl gencert \
  -ca=../00-Certificate-Authority/kubernetes-ca.pem \
  -ca-key=../00-Certificate-Authority/kubernetes-ca-key.pem \
  -config=../00-Certificate-Authority/kubernetes-ca-config.json \
  -hostname="${IPV4_ADDRESSES}",127.0.0.1,"${KUBE_API_CLUSTER_IP}","${KUBERNETES_HOSTNAMES}" \
  -profile=www \
  kubernetes-csr.json | cfssljson -bare kubernetes


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
