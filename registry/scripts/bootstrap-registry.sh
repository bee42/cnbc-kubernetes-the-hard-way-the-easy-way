#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

CONTAINERD_VERSION="${1}"
CNI_PLUGINS_VERSION="${2}"
NERDCTL_VERSION="${3}"

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

if ! command -v socat &> /dev/null || ! command -v conntrack &> /dev/null || ! command -v ipset &> /dev/null; then
  echo 'Installing socat conntrack and ipset'
  sudo apt update
  sudo apt -y install socat conntrack ipset
fi

echo 'Disabling swap'
sudo swapoff -a

if ! command -v nerdctl &> /dev/null || ! command -v runc &> /dev/null; then
  echo 'Installing containerd binaries'

  sudo mkdir -p \
    /etc/cni/net.d \
    /opt/cni/bin \
    /opt/nerdctl

  mkdir -p containerd
  tar -xvf "cri-containerd-${CONTAINERD_VERSION}-linux-$(get_arch).tar.gz" -C containerd
  mv containerd/usr/local/bin/crictl .
  mv containerd/usr/local/sbin/runc .
  sudo tar -xvf "cni-plugins-linux-$(get_arch)-v${CNI_PLUGINS_VERSION}.tgz" -C /opt/cni/bin/
  chmod +x crictl runc
  sudo mv crictl runc /usr/local/bin/
  sudo mv containerd/usr/local/bin/* /bin/

  sudo tar -xvf "nerdctl-full-${NERDCTL_VERSION}-linux-$(get_arch).tar.gz" -C /opt/nerdctl
  sudo cp /opt/nerdctl/bin/nerdctl /usr/local/bin/
  sudo chmod +s /usr/local/bin/nerdctl
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

sudo chgrp "$(id -gn)" /var/run/containerd/containerd.sock

sudo systemctl daemon-reload
declare -a SERVICES=('containerd')
sudo systemctl enable --now "${SERVICES[@]}"

function check_systemctl_status() {
  local UNIT="${1}"
  if ! grep -q 'active' <(systemctl is-active "${UNIT}"); then
    warn "${UNIT} status is NOT: active"
    return 1
  fi
}

for i in "${SERVICES[@]}"; do
  check_systemctl_status "${i}"
done

## start registries

if [[ ! -f /opt/registry/docker-compose.yml ]]; then
  mkdir -p /opt/registry
  mv docker-compose.yml /opt/registry
  mv cnbcmirror.yml /opt/registry
  mv cnbcregistry.yml /opt/registry
  cd /opt/registry
  nerdctl compose pull
  nerdctl compose up -d --wait --wait-timeout 60
fi

# check

# wait that container are download ready!
# healthy
# curl -s http://127.0.0.1:5000/v2/_catalog
# curl -s http://127.0.0.1:5001/v2/_catalog
