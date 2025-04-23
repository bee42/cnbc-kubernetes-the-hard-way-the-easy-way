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

echo 'Creating Kubernetes Controller Manager systemd service'

if [[ ! -f /var/lib/kubernetes/kube-controller-manager.kubeconfig ]]; then
  echo 'Moving kubernetes Controller Manager config to /var/lib/kubernetes/'
  sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/
fi

cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://kubernetes.io/docs/reference/command-line-tools-reference/kube-controller-manager/

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --allocate-node-cidrs=true \\
  --bind-address=127.0.0.1 \\
  --cluster-cidr=${CLUSTER_CIDR} \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/kubernetes-ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/kubernetes-ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/kubernetes-ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=${SERVICE_CLUSTER_IP_RANGE} \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

if [[ ! -f /var/lib/kubernetes/kube-scheduler.kubeconfig ]]; then
  echo 'Moving Kubernetes Scheduler config to /var/lib/kubernetes/'
  sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/
fi

sudo systemctl daemon-reload
sudo systemctl enable --now kube-controller-manager

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

check_systemctl_status "kube-controller-manager"
