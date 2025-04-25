#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# This works because we only have 1 controller
# logic will have to change if we have more than 1
if [[ "${MULTIPASS_ENABLED}" == 'on' ]] ; then
  KUBERNETES_VIRTUAL_IP_ADDRESS="$(multipass list | grep 'controller' | awk '{ print $1 }' | xargs multipass info | grep 'IPv4' | awk '{ print $2 }')"
else
  KUBERNETES_VIRTUAL_IP_ADDRESS=$(ssh "node-02" "hostname -I | awk '{print \$1}'")
fi

kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=../../00-certificates/00-Certificate-Authority/kubernetes-ca.pem \
  --embed-certs=true \
  --server=https://127.0.0.1:6443 \
  --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=../../00-certificates/01-admin-client/admin.pem \
  --client-key=../../00-certificates/01-admin-client/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=admin.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

# Bastion kubeconfg
# Choose prefix for name!
kubectl config set-cluster kubernetes-the-hard-way \
  --certificate-authority=../../00-certificates/00-Certificate-Authority/kubernetes-ca.pem \
  --embed-certs=true \
  --server=https://${KUBERNETES_VIRTUAL_IP_ADDRES):6443 \
  --kubeconfig=admin-client.kubeconfig

kubectl config set-credentials admin \
  --client-certificate=../../00-certificates/01-admin-client/admin.pem \
  --client-key=../../00-certificates/01-admin-client/admin-key.pem \
  --embed-certs=true \
  --kubeconfig=adminn-client.kubeconfig

kubectl config set-context default \
  --cluster=kubernetes-the-hard-way \
  --user=admin \
  --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=adminn-client.kubeconfig