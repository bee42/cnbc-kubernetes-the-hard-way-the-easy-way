#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

CONTAINERD_VERSION="${1}"
CNI_PLUGINS_VERSION="${2}"
DNS_CLUSTER_IP="${3}"
REGISTRY_IP="${4}"
KUBE_PROXY_ENABLED="${5}"
CLUSTER_CIDR="${6}"
CLUSTER_DOMAIN="${7:-cluster.local}"

function get_arch() {
  case "$(uname -m)" in
    armv5*) echo -n "armv5";;
    armv6*) echo -n "armv6";;
    armv7*) echo -n "armv7";;
    arm64) echo -n "arm64";;
    aarch64) echo -n "arm64";;
    x86) echo -n "386";;
    x86_64) echo -n "amd64";;
    i686) echo -n "386";;
    i386) echo -n "386";;
  esac
}

if ! grep 'controller-cnbc-k8s' /etc/hosts &> /dev/null; then
  # shellcheck disable=SC2002
  cat multipass-hosts | sudo tee -a /etc/hosts
  sudo /bin/sh -c "echo \"${REGISTRY_IP} cnbc-mirror cnbc-registry\" >>/etc/hosts"
fi

if ! command -v socat &> /dev/null || ! command -v conntrack &> /dev/null || ! command -v ipset &> /dev/null; then
  echo 'Installing socat conntrack and ipset'
  sudo apt update
  sudo apt -y install socat conntrack ipset
fi

echo 'Disabling swap'
sudo swapoff -a

if ! command -v kubectl &> /dev/null || ! command -v kube-proxy &> /dev/null || ! command -v kubelet &> /dev/null || ! command -v runc &> /dev/null; then
  echo 'Installing kubernetes worker binaries'

  sudo mkdir -p \
    /etc/cni/net.d \
    /opt/cni/bin \
    /var/lib/kubelet \
    /var/lib/kube-proxy \
    /var/lib/kubernetes \
    /var/run/kubernetes

  mkdir containerd
  tar -xvf "cri-containerd-${CONTAINERD_VERSION}-linux-$(get_arch).tar.gz" -C containerd
  mv containerd/usr/local/bin/crictl .
  mv containerd/usr/local/sbin/runc .
  sudo tar -xvf "cni-plugins-linux-$(get_arch)-v${CNI_PLUGINS_VERSION}.tgz" -C /opt/cni/bin/
  chmod +x crictl kubectl kube-proxy kubelet runc
  sudo mv crictl kubectl kube-proxy kubelet runc /usr/local/bin/
  sudo mv containerd/usr/local/bin/* /bin/
fi

if [[ ! -f /etc/containerd/config.toml ]]; then
  echo 'Creating the containerd configuration file and systemd service'
  sudo mkdir -p /etc/containerd/
  cat << EOF | sudo tee /etc/containerd/config.toml
version = 2
root = "/var/lib/containerd"
state = "/run/containerd"

[plugins]
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".containerd]
      default_runtime_name = "runc"
      snapshotter = "overlayfs"
  [plugins."io.containerd.runtime.v1.linux"]
    runtime = "runc"
    runtime_root = ""

  [plugins."io.containerd.grpc.v1.cri".registry]
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
        endpoint = ["http://cnbc-mirror:5001", "https://registry-1.docker.io"]
EOF

  cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF
fi

if [[ ! -f /etc/crictl.yaml ]]; then
  cat <<EOF | sudo tee /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: false
EOF
fi

if [[ ! -f /var/lib/kubelet/kubelet-config.yaml || ! -f /var/lib/kubelet/kubeconfig || ! -f /etc/cni/net.d/99-loopback.conf ]]; then
  echo 'Creating kubelet configuration'

  cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "name": "lo",
    "type": "loopback"
}
EOF

  sudo mv "${HOSTNAME}"-key.pem "${HOSTNAME}".pem /var/lib/kubelet/
  sudo mv "${HOSTNAME}".kubeconfig /var/lib/kubelet/kubeconfig
  sudo mv kubernetes-ca.pem /var/lib/kubernetes/

  cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/kubernetes-ca.pem"
authorization:
  mode: Webhook
clusterDomain: "${CLUSTER_DOMAIN}"
clusterDNS:
  - "${DNS_CLUSTER_IP}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
registerNode: true
containerRuntimeEndpoint: "unix:///var/run/containerd/containerd.sock"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
fi

if [ "$KUBE_PROXY_ENABLED" == "on" ] ; then

if [[ ! -f /var/lib/kube-proxy/kubeconfig || ! -f /var/lib/kube-proxy/kube-proxy-config.yaml || ! -f /etc/systemd/system/kube-proxy.service ]]; then
  echo 'Creating kube-proxy config'
  sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig
  cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "${CLUSTER_CIDR}"
EOF

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://kubernetes.io/docs/reference/command-line-tools-reference/kube-proxy/

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

fi

declare -a K8S_SERVICES=('containerd' 'kubelet' 'kube-proxy')

else

declare -a K8S_SERVICES=('containerd' 'kubelet')

fi

sudo systemctl daemon-reload
sudo systemctl enable --now "${K8S_SERVICES[@]}"

function check_systemctl_status() {
  local UNIT="${1}"
  if ! grep -q 'active' <(systemctl is-active "${UNIT}"); then
    warn "${UNIT} status is NOT: active"
    return 1
  fi
}

for i in "${K8S_SERVICES[@]}"; do
  check_systemctl_status "${i}"
done

function get_node_status() {
  kubectl get nodes \
    --kubeconfig /var/lib/kubelet/kubeconfig ${HOSTNAME} | \
    grep "${HOSTNAME}" | awk '{ print $2 }'
}

counter=0

until [ $counter -eq 5 ] || [[ "$(get_node_status)" != 'Ready' ]]; do
  echo "Node ${HOSTNAME} is NOT ready, will sleep for ${counter} seconds and check again"
  sleep $(( counter++ ))
done
