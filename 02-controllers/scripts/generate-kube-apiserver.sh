#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

SERVICE_CLUSTER_IP_RANGE="${1}"
SERVICE_NODE_PORT_RANGE="${2}"
CLUSTER_CIDR="${3}"
KUBE_API_CLUSTER_IP="${4}"
CLUSTER_DOMAIN="${5:-cluster.local}"

declare -a INTERNAL_IPS=() COMPUTER_IPV4_ADDRESSES=()
while IFS= read -r ip; do
  if [[ -n ${ip} ]]; then
    INTERNAL_IPS+=("${ip}")
  fi
done < <(hostname -I | tr '[:space:]' '\n')
VERSION_REGEX='([0-9]*)\.'

for ip in "${INTERNAL_IPS[@]}"; do
  if grep -E "${VERSION_REGEX}" <<< "${ip}" > /dev/null; then
    COMPUTER_IPV4_ADDRESSES+=("${ip}")
  fi
done

echo 'Creating kube-apiserver systemd service'

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${COMPUTER_IPV4_ADDRESSES[0]} \\
  --allow-privileged=true \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/etc/kubernetes/kubernetes-ca.pem \\
  --enable-admission-plugins=NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --etcd-cafile=/etc/kubernetes/etcd-ca.pem \\
  --etcd-certfile=/etc/kubernetes/apiserver-etcd-client.pem \\
  --etcd-keyfile=/etc/kubernetes/apiserver-etcd-client-key.pem \\
  --etcd-servers=https://${COMPUTER_IPV4_ADDRESSES[0]}:2379 \\
  --event-ttl=1h \\
  --encryption-provider-config=/etc/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/etc/kubernetes/kubelet-ca.pem \\
  --kubelet-client-certificate=/etc/kubernetes/kubelet-apiserver-client.pem \\
  --kubelet-client-key=/etc/kubernetes/kubelet-apiserver-client-key.pem \\
  --runtime-config=api/all=true \\
  --service-account-issuer=${KUBE_API_CLUSTER_IP} \\
  --service-account-key-file=/etc/kubernetes/service-account.pem \\
  --service-account-signing-key-file=/etc/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=${SERVICE_CLUSTER_IP_RANGE} \\
  --service-node-port-range=${SERVICE_NODE_PORT_RANGE} \\
  --tls-cert-file=/etc/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/etc/kubernetes/kubernetes-key.pem \\
  --proxy-client-cert-file=/etc/kubernetes/front-proxy-client.pem \\
  --proxy-client-key-file=/etc/kubernetes/front-proxy-client-key.pem \\
  --requestheader-allowed-names=front-proxy-client \\
  --requestheader-client-ca-file=/etc/kubernetes/kubernetes-front-proxy-ca.pem \\
  --requestheader-extra-headers-prefix=X-Remote-Extra- \\
  --requestheader-group-headers=X-Remote-Group \\
  --requestheader-username-headers=X-Remote-User \\
  --egress-selector-config-file=/etc/kubernetes/konnectivity-egress-selector-configuration.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now kube-apiserver

echo 'If running on Google Cloud remember to check https://github.com/kelseyhightower/kubernetes-the-hard-way/blob/master/docs/08-bootstrapping-kubernetes-controllers.md#enable-http-health-checks'

echo 'Will test components now:'
# shellcheck disable=SC2016
echo '- `kubectl get componentstatuses --kubeconfig admin.kubeconfig`'
# shellcheck disable=SC2016
echo '- if on GCP `curl -H "Host: kubernetes.default.svc.${CLUSTER_DOMAIN}" -i http://127.0.0.1/healthz`'

counter=0

until [ $counter -eq 10 ] || kubectl get componentstatuses --kubeconfig admin.kubeconfig &> /dev/null ; do
  echo "Kube API Server is not ready yet, will sleep for ${counter} seconds and check again"
  sleep $((counter++))
done

function check_systemctl_status() {
  local UNIT="${1}"
  if ! grep -q 'active' <(systemctl is-active "${UNIT}"); then
    warn "${UNIT} status is NOT: active"
    return 1
  fi
}

check_systemctl_status "kube-apiserver"
