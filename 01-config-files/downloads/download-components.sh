#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

. "${GITROOT}"/env.sh

ARCH=${ARCH:-$(get_arch)}
# Download kubernetes components once then distribute them to controller(s) and
# agents
msg_info 'Downloading kubernetes components'
# Define files and URLs 
declare -A FILES

FILES=(
  ["kube-apiserver"]="https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/${ARCH}/kube-apiserver"
  ["kube-controller-manager"]="https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/${ARCH}/kube-controller-manager"
  ["kube-scheduler"]="https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/${ARCH}/kube-scheduler"
  ["kubectl"]="https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/${ARCH}/kubectl"
  ["kube-proxy"]="https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/${ARCH}/kube-proxy"
  ["kubelet"]="https://dl.k8s.io/release/v${KUBERNETES_VERSION}/bin/linux/${ARCH}/kubelet"
  ["etcd-v${ETCD_VERSION}-linux-${ARCH}.tar.gz"]="https://github.com/etcd-io/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-${ARCH}.tar.gz"
  ["cni-plugins-linux-${ARCH}-v${CNI_PLUGINS_VERSION}.tgz"]="https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGINS_VERSION}/cni-plugins-linux-${ARCH}-v${CNI_PLUGINS_VERSION}.tgz"
  ["cri-containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"]="https://github.com/containerd/containerd/releases/download/v${CONTAINERD_VERSION}/cri-containerd-${CONTAINERD_VERSION}-linux-${ARCH}.tar.gz"
  ["nerdctl-full-${NERDCTL_VERSION}-linux-${ARCH}.tar.gz"]="https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-full-${NERDCTL_VERSION}-linux-${ARCH}.tar.gz"
)

for file in "${FILES[@]}"; do
  url="${FILES[$file]}"
  if [ -f $file ] ; then
    msg_info "Downloading $file from $url"
    curl -fSL --ssl-reqd -o "$file" "$url"
  fi
done

if [ -f proxy-server ] ; then
  msg_info "Downloading konnectivity proxy-server from image registry.k8s.io/kas-network-proxy/proxy-server:v${KONNECTIFITY_VERSION}"
  crane export registry.k8s.io/kas-network-proxy/proxy-server:v${KONNECTIFITY_VERSION} proxyserver.tar
  tar -xvf proxyserver.tar proxy-server
  rm proxyserver.tar
fi
