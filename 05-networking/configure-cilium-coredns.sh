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

KUBERNETES_VIRTUAL_IP_ADDRESS="$(multipass list | grep 'controller' | awk '{ print $1 }' | xargs multipass info | grep 'IPv4' | awk '{ print $2 }')"

helm install cilium cilium/cilium --version "${CILIUM_CHART_VERSION}" \
    --namespace kube-system \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true \
    --set ingressController.enabled=true \
    --set ingressController.loadbalancerMode=shared \
    --set k8sServiceHost=${KUBERNETES_VIRTUAL_IP_ADDRESS} \
    --set k8sServicePort=6443 \
    --values cilium-values.yaml

kubectl apply -f ipam.yaml

echo 'Installing metrics-server'

helm upgrade --install metrics-server metrics-server/metrics-server --version "${METRICS_SERVER_CHART_VERSION}" \
    --namespace kube-system 
