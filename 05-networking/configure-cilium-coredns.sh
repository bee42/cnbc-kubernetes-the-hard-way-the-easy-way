#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

echo 'Adding cilium, metrics-server and coredns helm repos'

helm repo add coredns https://coredns.github.io/helm
helm repo add cilium https://helm.cilium.io/
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/

echo 'Updating helm repos'

helm repo update

echo 'Installing coredns'

helm install coredns coredns/coredns --version "${COREDNS_CHART_VERSION}" \
    --namespace kube-system \
    --set "service.clusterIP=${DNS_CLUSTER_IP}"

echo 'Installing cilium'

_IP_ADDRESS="$(multipass list | grep 'controller' | awk '{ print $1 }' | xargs multipass info | grep 'IPv4' | awk '{ print $2 }')"
if [ "$_IP_ADDRESS" == "--" ]; then
  export KUBERNETES_VIRTUAL_IP_ADDRESS="192.168.67.3"
else
  export KUBERNETES_VIRTUAL_IP_ADDRESS="$_IP_ADDRESS"
fi

helm install cilium cilium/cilium --version "${CILIUM_CHART_VERSION}" \
    --namespace kube-system \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true \
    --set ingressController.enabled=true \
    --set ingressController.loadbalancerMode=shared \
    --set k8sServiceHost="${KUBERNETES_VIRTUAL_IP_ADDRESS}" \
    --set k8sServicePort=6443 \
    --set ipv4NativeRoutingCIDR="${CLUSTER_CIDR}" \
    --values cilium-values.yaml

cat >ipam.yaml <<EOF
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata:
  name: "blue-pool"
spec:
  blocks:
  - cidr: "$(echo "${KUBERNETES_VIRTUAL_IP_ADDRESS}" | awk -F "." '{ printf "%s.%s.%s.128/28", $1,$2,$3 }')"
EOF

kubectl apply -f ipam.yaml

echo 'Installing metrics-server'

helm upgrade --install metrics-server metrics-server/metrics-server \
    --version "${METRICS_SERVER_CHART_VERSION}" \
    --namespace kube-system
