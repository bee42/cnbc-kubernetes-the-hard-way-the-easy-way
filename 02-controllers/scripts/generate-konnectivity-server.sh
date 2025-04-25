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

echo 'Creating konnectivity proxy server systemd service'

if [[ ! -f /etc/kubernetes/konnectivity-server.kubeconfig ]]; then
  echo 'Moving konnectivity config to /etc/kubernetes/'
  sudo mv konnectivity-server.kubeconfig /etc/kubernetes/
fi

mkdir -p /etc/kubernetes/konnectivity-server/

cat <<EOF | sudo tee /etc/systemd/system/konnectivity-server.service
[Unit]
Description=konnectivity server
Documentation=https://github.com/kubernetes-sigs/apiserver-network-proxy/blob/master/examples/kubernetes/konnectivity-server.yaml

[Service]
ExecStart=/usr/local/bin/proxy-server \\
  --log-file=/var/log/konnectivity-server.log \\
  --logtostderr=false \\
  --log-file-max-size=0 \\
  --uds-name=/var/lib/kubernetes/konnectivity-server/konnectivity-server.socket \\
  --cluster-cert=/etc/kubernetes/kubernetes.pem \\
  --cluster-key=/etc/kubernetes/kubernetes-key.pem \\
  --server-port=0 \\
  --agent-port=8091 \\
  --health-port=8092 \\
  --admin-port=8093 \\
  --keepalive-time=1h \\
  --mode=grpc \\
  --agent-namespace=kube-system \\
  --agent-service-account=konnectivity-agent \\
  --kubeconfig=/etc/kubernetes/konnectivity-server.kubeconfig \\
  --authentication-audience=system:konnectivity-server
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now konnectivity-server

function check_systemctl_status() {
  local UNIT="${1}"
  if ! grep -q 'active' <(systemctl is-active "${UNIT}"); then
    warn "${UNIT} status is NOT: active"
    return 1
  fi
}

check_systemctl_status "konnectivity-server"
