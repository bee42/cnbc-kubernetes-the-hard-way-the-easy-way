#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# This works because we only have 1 controller
# logic will have to change if we have more than 1
if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
  KUBERNETES_VIRTUAL_IP_ADDRESS="$(multipass list | grep 'controller' | awk '{ print $1 }' | xargs multipass info | grep 'IPv4' | awk '{ print $2 }')"
  declare -a MINIONS=( $(multipass list | grep 'worker' | awk '{ print $1 }' ) )
else
  KUBERNETES_VIRTUAL_IP_ADDRESS=$(ssh "node-02" "hostname -I | awk '{print \$1}'")
  declare -a MINIONS=( 'node-03' 'node-04' )
fi

for instance in "${MINIONS[@]}"; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=../../00-certificates/00-Certificate-Authority/kubernetes-ca.pem \
    --embed-certs=true \
    --server=https://"${KUBERNETES_VIRTUAL_IP_ADDRESS}":6443 \
    --kubeconfig="${instance}".kubeconfig

  kubectl config set-credentials system:node:"${instance}" \
    --client-certificate=../../00-certificates/02-kubelet-client/"${instance}"-client.pem \
    --client-key=../../00-certificates/02-kubelet-client/"${instance}"-client-key.pem \
    --embed-certs=true \
    --kubeconfig="${instance}".kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:"${instance}" \
    --kubeconfig="${instance}".kubeconfig

  kubectl config use-context default --kubeconfig="${instance}".kubeconfig
done
