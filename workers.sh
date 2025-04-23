#!/usr/bin/env bash
source ./check_default.sh

msg_info 'Push worker setup scripts'

cd 03-workers/ || exit
bash transfer-shell-scripts.sh
cd - || exit

msg_info 'Configuring the Kubernetes workers'

for i in 'worker-1-cnbc-k8s' 'worker-2-cnbc-k8s'; do
  msg_info "Provisioning ${i}"
  multipass exec "${i}" -- bash bootstrap-workers.sh "${CONTAINERD_VERSION}" "${CNI_PLUGINS_VERSION}" "${DNS_CLUSTER_IP}" "${REGISTRY_IP}" "${KUBE_PROXY_ENABLED}" "${CLUSTER_CIDR}" "${CLUSTER_DOMAIN}"
done