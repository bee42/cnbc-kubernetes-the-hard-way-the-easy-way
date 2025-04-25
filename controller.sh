#!/usr/bin/env bash
source ./check_deps.sh

msg_info 'Push controller setup scripts'

if ! command -v "multipass" &> /dev/null; then
  REMOTE_EXEC="ssh node-02"
else
  REMOTE_EXEC="multipass exec controller-cnbc-k8s -- bash"
fi

cd 02-controllers/ || exit
bash transfer-shell-scripts.sh
cd - || exit

msg_info 'Configuring the Kubernetes control plane'

msg_info 'Configuring and create etcd service'

${REMOTE_EXEC} ./generate-etcd-systemd.sh "${ETCD_VERSION}"

msg_info 'prepare control-plane'

${REMOTE_EXEC} ./prepare-control-plane.sh

msg_info 'Configuring and create apiserver'

${REMOTE_EXEC} ./generate-kube-apiserver.sh "${SERVICE_CLUSTER_IP_RANGE}" "${SERVICE_NODE_PORT_RANGE}" "${CLUSTER_CIDR}" "${KUBE_API_CLUSTER_IP}" "${CLUSTER_DOMAIN}"

msg_info 'Configuring and create controller-manager'

${REMOTE_EXEC} ./generate-kube-controller-manager.sh "${SERVICE_CLUSTER_IP_RANGE}" "${SERVICE_NODE_PORT_RANGE}" "${CLUSTER_CIDR}" "${KUBE_API_CLUSTER_IP}" "${CLUSTER_DOMAIN}"

msg_info 'Configuring and create scheduler'

${REMOTE_EXEC} ./generate-kube-scheduler.sh "${SERVICE_CLUSTER_IP_RANGE}" "${SERVICE_NODE_PORT_RANGE}" "${CLUSTER_CIDR}" "${KUBE_API_CLUSTER_IP}" "${CLUSTER_DOMAIN}"

msg_info 'Configuring and create konnectivity-server'

${REMOTE_EXEC} ./generate-konnectivity-server "${SERVICE_CLUSTER_IP_RANGE}" "${SERVICE_NODE_PORT_RANGE}" "${CLUSTER_CIDR}" "${KUBE_API_CLUSTER_IP}" "${CLUSTER_DOMAIN}"

msg_info 'Generate the api server kubelet client RBAC roles'

${REMOTE_EXEC} ./generate-kubelet-rbac-authorization.sh
