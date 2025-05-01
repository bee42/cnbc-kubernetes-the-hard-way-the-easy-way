#!/usr/bin/env bash
# Enable bash's unofficial strict mode
GITROOT=$(git rev-parse --show-toplevel)
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/strict-mode
# shellcheck disable=SC1090,SC1091
. "${GITROOT}"/lib/utils
strictMode

. "${GITROOT}"/env.sh

declare -a COMMON_FILES=(
  './downloads/kubectl'
  'k8s-hosts'
)
declare -a CONTROLLER_FILES=(
  './admin/admin.kubeconfig'
  './kube-controller-manager/kube-controller-manager.kubeconfig'
  './kube-scheduler/kube-scheduler.kubeconfig'
  './konnectivity-server/konnectivity-server.kubeconfig'
  'encryption/encryption-config.yaml'
  './downloads/kube-apiserver'
  './downloads/kube-controller-manager'
  './downloads/kube-scheduler'
  './downloads/proxy-server'
  "./downloads/etcd-v${ETCD_VERSION}-linux-$(get_arch).tar.gz"
)

declare -a WORKER_FILES=(
  './kube-proxy/kube-proxy.kubeconfig'
  './downloads/kube-proxy'
  './downloads/kubelet'
  "./downloads/cni-plugins-linux-$(get_arch)-v${CNI_PLUGINS_VERSION}.tgz"
  "./downloads/cri-containerd-${CONTAINERD_VERSION}-linux-$(get_arch).tar.gz"
)

declare -a REIGSTRY_FILES=(
  "./registry/docker-compose.yml"
  "./registry/cnbcmirror.yml"
  "./registry/cnbcregistry.yml"
  "./downloads/cni-plugins-linux-$(get_arch)-v${CNI_PLUGINS_VERSION}.tgz"
  "./downloads/cri-containerd-${CONTAINERD_VERSION}-linux-$(get_arch).tar.gz"
  "./downloads/nerdctl-full-${NERDCTL_VERSION}-linux-$(get_arch).tar.gz"
)

if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
  multipass list | grep -E -v "Name|\-\-" | grep "cnbc-k8s" | awk '{var=sprintf("%s\t%s",$3,$1); print var}' > k8s-hosts
  declare -a MINIONS=( $(multipass list | grep 'worker' | awk '{ print $1 }' ) )
  declare -a GRUS=( $(multipass list | grep 'controller' | awk '{ print $1 }' ) )
  declare -a REIGSTRIES=( $(multipass list | grep 'registry' | awk '{ print $1 }' ) )
else
  declare -a MINIONS=( 'node-03' 'node-04' )
  declare -a GRUS=( 'node-02' )
  declare -a REIGSTRIES=( 'node-01' )

  for instance in "${MINIONS[@]}" "${GRUS[@]}"; do
    INTERNAL_IP=$(ssh "${instance}" "hostname -I | awk '{print \$1}'")
    echo "${INTERNAL_IP}\t$|instance}" >>k8s-hosts
  done
fi

# transfer files
for instance in "${GRUS[@]}"; do
  for file in "${COMMON_FILES[@]}" "${CONTROLLER_FILES[@]}"; do
    transfer_file "${file}" "${instance}"
  done
done

for instance in "${MINIONS[@]}"; do
  for file in "./kubelet/${instance}.kubeconfig" "${COMMON_FILES[@]}" "${WORKER_FILES[@]}"; do
    transfer_file "${file}" "${instance}"
  done
done

if [ "$REGISTRY_MODE" == "on" ] then
  for instance in "${REIGSTRIES[@]}"; do
    for file in "${REIGSTRY_FILES[@]}" ; do
      transfer_file "${file}" "${instance}"
    done
  done
fi

rm -f k8s-hosts
