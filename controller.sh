#!/usr/bin/env bash
source ./check_default.sh

msg_info 'Push controller setup scripts'

cd 02-controllers/ || exit
bash transfer-shell-scripts.sh
cd - || exit

msg_info 'Configuring the Kubernetes control plane'

msg_info 'Configuring and create etcd service'

multipass exec controller-cnbc-k8s -- bash generate-etcd-systemd.sh "${ETCD_VERSION}"

msg_info 'prepare control-plane'

multipass exec controller-cnbc-k8s -- bash prepare-control-plane.sh

msg_info 'Configuring and create apiserver'

multipass exec controller-cnbc-k8s -- bash generate-kube-apiserver.sh "${SERVICE_CLUSTER_IP_RANGE}" "${SERVICE_NODE_PORT_RANGE}" "${CLUSTER_CIDR}" "${KUBE_API_CLUSTER_IP}" "${CLUSTER_DOMAIN}"

msg_info 'Configuring and create controller-manager'

multipass exec controller-cnbc-k8s -- bash generate-kube-controller-manager.sh "${SERVICE_CLUSTER_IP_RANGE}" "${SERVICE_NODE_PORT_RANGE}" "${CLUSTER_CIDR}" "${KUBE_API_CLUSTER_IP}" "${CLUSTER_DOMAIN}"

msg_info 'Configuring and create scheduler'

multipass exec controller-cnbc-k8s -- bash generate-kube-scheduler.sh "${SERVICE_CLUSTER_IP_RANGE}" "${SERVICE_NODE_PORT_RANGE}" "${CLUSTER_CIDR}" "${KUBE_API_CLUSTER_IP}" "${CLUSTER_DOMAIN}"

msg_info 'Generate the api server kubelet client RBAC roles'

multipass exec controller-cnbc-k8s -- bash generate-kubelet-rbac-authorization.sh
