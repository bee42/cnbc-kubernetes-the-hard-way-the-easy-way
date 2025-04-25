#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

ETCD_VERSION="${1}"

function get_arch() {
  case "$(uname -m)" in
    armv5*) echo -n "armv5";;
    armv6*) echo -n "armv6";;
    armv7*) echo -n "armv7";;
    aarch64) echo -n "arm64";;
    x86) echo -n "386";;
    x86_64) echo -n "amd64";;
    i686) echo -n "386";;
    i386) echo -n "386";;
  esac
}

ARCH="$(get_arch)"

if ! grep '$(cat k8s-hosts | head -1 | awk '{print $2}')' /etc/hosts &> /dev/null; then
  # shellcheck disable=SC2002
  cat k8s-hosts | sudo tee -a /etc/hosts
fi

if [[ ! -x $(command -v etcd) || ! -x $(command -v etcdctl) ]]; then
  tar -xvf etcd-v"${ETCD_VERSION}"-linux-"${ARCH}".tar.gz
  sudo mv etcd-v"${ETCD_VERSION}"-linux-"${ARCH}"/etcd* /usr/local/bin/
  rm -rf etcd-v"${ETCD_VERSION}"-linux-"${ARCH}".tar.gz etcd-v"${ETCD_VERSION}"-linux-"${ARCH}"/
fi

if [[ ! -f /etc/etcd/etcd-server.pem || ! -f /etc/etcd/etcd-server-key.pem ]]; then
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo chmod -R 0700 /var/lib/etcd
  sudo cp etcd-ca.pem etcd-server-key.pem etcd-server.pem etcd-peer.pem etcd-peer-key.pem etcd-healthcheck-client.pem etcd-healthcheck-client-key.pem /etc/etcd/
fi

declare -a INTERNAL_IPS=() COMPUTER_IPV4_ADDRESSES=()
while IFS= read -r ip; do
  if [[ -n ${ip} ]]; then
    INTERNAL_IPS+=("${ip}")
  fi
done < <(hostname -I | tr '[:space:]' '\n')
ETCD_NAME="$(hostname -s)"
VERSION_REGEX='([0-9]*)\.'

for ip in "${INTERNAL_IPS[@]}"; do
  if grep -E "${VERSION_REGEX}" <<< "${ip}" > /dev/null; then
    COMPUTER_IPV4_ADDRESSES+=("${ip}")
  fi
done

echo 'Creating etcd systemd unit'

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://etcd.io

[Service]
Type=notify
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/etcd-server.pem \\
  --key-file=/etc/etcd/etcd-server-key.pem \\
  --peer-cert-file=/etc/etcd/etcd-peer.pem \\
  --peer-key-file=/etc/etcd/etcd-peer-key.pem \\
  --trusted-ca-file=/etc/etcd/etcd-ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/etcd-ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${COMPUTER_IPV4_ADDRESSES[0]}:2380 \\
  --listen-peer-urls https://${COMPUTER_IPV4_ADDRESSES[0]}:2380 \\
  --listen-client-urls https://${COMPUTER_IPV4_ADDRESSES[0]}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${COMPUTER_IPV4_ADDRESSES[0]}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster ${ETCD_NAME}=https://${COMPUTER_IPV4_ADDRESSES[0]}:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

echo 'Reloading systemd, enabling and starting etcd systemd service'

sudo systemctl daemon-reload
sudo systemctl enable --now etcd

echo 'Listing etcd members'

sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/etcd-ca.pem \
  --cert=/etc/etcd/etcd-healthcheck-client.pem \
  --key=/etc/etcd/etcd-healthcheck-client-key.pem
